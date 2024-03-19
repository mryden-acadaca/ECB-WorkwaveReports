class GenerateReportJob < ApplicationJob
  queue_as :default

  def perform(args)
    if args[:type] == 'delivery'
      generate_delivery_report(args)
    end
    if args[:type] == 'pickup'
      generate_pickup_report(args)
    end
    if args[:type] == 'ups'
      generate_ups_report(args)
    end
    if args[:type] == 'summary'
      generate_summary_report(args)
    end
  end

  private

  def generate_ups_report(args)
    shopify_service = ShopifyService.new

    report_date = args[:params]['report_date'] ? args[:params]['report_date'] : '20230518'
    report_zone = args[:params]['delivery_zone']

    @report_territory = 'ALL'
    @final_orders = []

    if report_zone == '5,6'
      @report_territory = 'GA'
    end

    if report_zone == '1,2,4,10'
      @report_territory = 'NJ'
    end

    @parsed_report_date = Date.parse(report_date).strftime("%A, %B %d, %Y")

    tag = Date.parse(report_date).strftime("%m/%d/%Y")

    params = {
      :tag => "us-#{tag}",
    }

    @ups_orders = shopify_service.list_orders(params)

    @ups_orders.each do |order|
      should_include = false
      if @report_territory == 'ALL'
        should_include = true
      else
        location = order['note_attributes'].find { |a| a['name'] == 'Location Name' }
        if location['value'] == @report_territory
          should_include = true
        end
      end

      if order['cancelled_at'] || order['closed_at']
        should_include = false
      end

      if order.include? 'internal-order'
        should_include = false
      end

      if should_include
        total_quantity = order['line_items'].sum { |p| p['vendor'] == 'Eat Clean Bro LLC' ? p['quantity'] : 0 }
        order['total_quantity'] = total_quantity
        @final_orders.push(order)
      end
    end

    content = ReportsController.render(
      template: 'reports/template_ups',
      assigns: {
        final_orders: @final_orders,
        parsed_report_date: @parsed_report_date,
        report_territory: @report_territory,
      }
    )

    report = Report.create(
      :template => content,
      :generate_mode => 'ups',
      :location => args[:params]['delivery_zone'],
      :delivery_date => args[:params]['report_date'],
    )

    UserNotifierMailer.send_report_email(args[:email], report).deliver
  end

  def generate_pickup_report(args)
    shopify_service = ShopifyService.new

    report_date = args[:params]['report_date'] ? args[:params]['report_date'] : '20230518'
    report_zone = args[:params]['delivery_zone']

    @report_territory = 'ALL'

    if report_zone == '5,6'
      @report_territory = 'GA'
    end

    if report_zone == '1,2,4,10'
      @report_territory = 'NJ'
    end

    @parsed_report_date = Date.parse(report_date).strftime("%A, %B %d, %Y")
    tag = Date.parse(report_date).strftime("%m/%d/%Y")
    params = {
      :tag => "p-#{tag}",
    }

    @pickup_orders = shopify_service.list_orders(params)

    @pickup_orders.each do |order|
      total_quantity = order['line_items'].sum { |p| p['vendor'] == 'Eat Clean Bro LLC' ? p['quantity'] : 0 }
      order['total_quantity'] = total_quantity
      order['customer_note'] = order['note_attributes'].find { |a| a['name'] == 'Delivery Note' }
      order['location'] = order['note_attributes'].find { |a| a['name'] == 'Pickup Location' }
      order['location_name'] = order['location'] ? order['location']['value'] : ''
    end

    @pickup_eatontown_orders = []
    @pickup_freehold_orders = []
    @pickup_point_orders = []

    @pickup_orders.each do |order|
      order['customer']['name'] = "#{order['customer']['first_name']} #{order['customer']['last_name']}"

      if order['cancelled_at'] || order['closed_at'] || @report_territory == 'GA' || order['tags'].include?('internal-order')
        next
      else
        if order['location_name'].downcase.include? ('eatontown')
          @pickup_eatontown_orders.push(order)
        end
        if order['location_name'].downcase.include? ('freehold')
          @pickup_freehold_orders.push(order)
        end
        if order['location_name'].downcase.include? ('pleasant')
          @pickup_point_orders.push(order)
        end
      end
    end

    @pickup_eatontown_orders = @pickup_eatontown_orders.sort_by { |hsh| hsh['customer']['name'] }
    @pickup_freehold_orders = @pickup_freehold_orders.sort_by { |hsh| hsh['customer']['name'] }
    @pickup_point_orders = @pickup_point_orders.sort_by { |hsh| hsh['customer']['name'] }

    @pickup_orders = @pickup_eatontown_orders + @pickup_freehold_orders + @pickup_point_orders

    content = ReportsController.render(
      template: 'reports/template_pickup',
      assigns: {
        parsed_report_date: @parsed_report_date,
        pickup_orders: @pickup_orders,
      }
    )

    report = Report.create(
      :template => content,
      :generate_mode => 'pickup',
      :location => args[:params]['delivery_zone'],
      :delivery_date => args[:params]['report_date'],
    )

    UserNotifierMailer.send_report_email(args[:email], report).deliver
  end

  def generate_delivery_report(args)
    report_date = args[:params]['report_date'] ? args[:params]['report_date'] : '20230518'
    report_zone = args[:params]['delivery_zone'] ? args[:params]['delivery_zone'].split(',') : [1]
    report_territory = ENV['NJ_TERRITORY_ID']
    @parsed_report_date = Date.parse(report_date).strftime("%A, %B %d, %Y")

    shopify_service = ShopifyService.new
    work_wave_service = WorkWaveService.new

    @final_orders = {}

    if report_zone.include? "1"
      report_territory = ENV['NJ_TERRITORY_ID']
    else
      if report_zone.include? "5"
        report_territory = ENV['AT_TERRITORY_ID']
      end
    end

    result = work_wave_service.list_routes(report_territory, report_date)

    if result
      vehicles_data = result['vehicles']
      routes_data = result['routes']
      orders_data = result['orders']

      vehicles = {}

      vehicles_data.each do |vehicle|
        vehicle_id = vehicle[1]['id']
        vehicle_external_id = vehicle[1]['externalId']
        vehicles[vehicle_id] = vehicle_external_id
      end

      vehicles = vehicles.sort_by { |k, s| s }

      routes = {}

      routes_data.each do |route|
        vehicle_id = route[1]['vehicleId']
        route_steps = route[1]['steps']
        deliveries = {}

        route_steps.each do |step|
          delivery_type = step['type']
          if delivery_type == 'delivery'
            display_label = step['displayLabel']
            order_id = step['orderId']
            deliveries[order_id] = display_label
          end
        end
        routes[vehicle_id] = deliveries
      end

      ordered_deliveries = {}
      sorted_routes = {}

      vehicles.each do |vehicle|
        vehicle_id = vehicle[0]
        sorted_routes[vehicle_id] = routes[vehicle_id]
      end

      sorted_routes.each do |sorted_route|
        ordered_deliveries = ordered_deliveries.merge(sorted_route[1])
      end

      orders = {}

      orders_data.each do |order|
        order_id = order[1]['id']
        crf_max = order[1]['delivery'] ? order[1]['delivery']['customFields']['crf/max'] : 1
        shopify_order_id = order[1]['delivery'] ? order[1]['delivery']['customFields']['magento order id'] : 1
        if crf_max == 1
          next
        else
          orders[order_id] = shopify_order_id
        end
      end

      workwave_orders = {}
      order_ids = []

      ordered_deliveries.each do |k, v|
        workwave_orders[k] = [v, orders[k]]
        order_ids.push(orders[k].to_i)
      end

      order_details = []

      if order_ids.length > 250
        order_ids.each_slice(200).to_a.each do |order_sub_ids|
          params = {
            :ids => order_sub_ids,
          }

          order_sub_details = shopify_service.list_orders_by_ids(params)

          if order_sub_details.body["data"]
            order_details = order_details + order_sub_details.body["data"]["nodes"]
          end
        end
      else
        params = {
          :ids => order_ids,
        }

        order_details = shopify_service.list_orders_by_ids(params)

        if order_details.body["data"]
          order_details = order_details.body["data"]["nodes"]
        end
      end

      workwave_orders.each do |order|
        payload = order_details.find { |o| o.present? ? o["id"] == "gid://shopify/Order/#{order[1][1].to_i}" : false }

        if payload
          total_quantity = payload['lineItems']['edges'].sum { |p| p['node']['vendor'] == "Eat Clean Bro LLC" ? p['node']['quantity'] : 0 }
          note = payload['customAttributes'].find { |a| a['key'] == 'Delivery Note' }
          @final_orders[order[1][1]] = {
            order: payload,
            total_quantity: total_quantity,
            customer_note: note,
            misc: order[1],
          }
        end
      end

      content = ReportsController.render(
        template: 'reports/template_delivery',
        assigns: {
          parsed_report_date: @parsed_report_date, final_orders: @final_orders
        }
      )

      report = Report.create(
        :template => content,
        :generate_mode => 'delivery',
        :location => args[:params]['delivery_zone'],
        :delivery_date => args[:params]['report_date'],
      )

      UserNotifierMailer.send_report_email(args[:email], report).deliver
    end
  end

  def generate_summary_report(args)
    shopify_service = ShopifyService.new
    report_date = args[:params]['report_date'] ? args[:params]['report_date'] : '20230518'
    report_zone = args[:params]['delivery_zone']
    @report_territory = 'ALL'
    created_at_min = Date.parse(report_date).in_time_zone('EST').beginning_of_day.iso8601
    created_at_max = Date.parse(report_date).in_time_zone('EST').end_of_day.iso8601
    orders = []

    tag = Date.parse(report_date).strftime("%m/%d/%Y")

    ups_order_ids = shopify_service.get_order_ids({
      :tag => "us-#{tag}",
    }).map {|o| o['node']['id']}

    delivery_order_ids = shopify_service.get_order_ids({
      :tag => "d-#{tag}",
    }).map {|o| o['node']['id']}
    pickup_order_ids = shopify_service.get_order_ids({
      :tag => "p-#{tag}",
    }).map {|o| o['node']['id']}

    if ups_order_ids.length > 100
      ups_order_ids.each_slice(100).to_a.each do |order_sub_ids|
        params = {
          :ids => order_sub_ids,
        }

        order_sub_details = shopify_service.list_day_orders(params)

        if order_sub_details.body && order_sub_details.body["data"]
          orders = orders + order_sub_details.body["data"]["nodes"]
        end
      end
    else
      params = {
        :ids => ups_order_ids,
      }

      order_details = shopify_service.list_day_orders(params)

      if order_details.body && order_details.body["data"]
        orders = orders + order_details.body["data"]["nodes"]
      end
    end

    if delivery_order_ids.length > 100
      delivery_order_ids.each_slice(100).to_a.each do |order_sub_ids|
        params = {
          :ids => order_sub_ids,
        }

        order_sub_details = shopify_service.list_day_orders(params)

        if order_sub_details.body && order_sub_details.body["data"]
          orders = orders + order_sub_details.body["data"]["nodes"]
        end
      end
    else
      params = {
        :ids => delivery_order_ids,
      }

      order_details = shopify_service.list_day_orders(params)

      if order_details.body && order_details.body["data"]
        orders = orders + order_details.body["data"]["nodes"]
      end
    end

    if pickup_order_ids.length > 100
      pickup_order_ids.each_slice(100).to_a.each do |order_sub_ids|
        params = {
          :ids => order_sub_ids,
        }

        order_sub_details = shopify_service.list_day_orders(params)

        if order_sub_details.body && order_sub_details.body["data"]
          orders = orders + order_sub_details.body["data"]["nodes"]
        end
      end
    else
      params = {
        :ids => pickup_order_ids,
      }

      order_details = shopify_service.list_day_orders(params)

      if order_details.body && order_details.body["data"]
        orders = orders + order_details.body["data"]["nodes"]
      end
    end

    if report_zone == '5,6'
      @report_territory = 'GA'
    end
    if report_zone == '1,2,4,10'
      @report_territory = 'NJ'
    end

    @parsed_report_date = Date.parse(report_date).strftime("%A, %B %d, %Y")

    @total_meals = 0
    @total_gift_meals = 0
    @total_credit_meals = 0

    @total_delivery_fees = 0.0
    @total_tax_collected = 0.0
    @total_tip_received = 0.0
    @total_tip_count = 0
    @total_product_revenue = 0.0

    @total_delivery_count = 0
    @total_pickup_count = 0
    @total_shipping_count = 0

    @total_credit_discount = 0.0
    @total_giftcard_discount = 0.0
    @total_discount = 0.0

    @total_credit_collected = 0.0
    @total_gift_collected = 0.0
    @total_collected = 0.0

    @total_refunded_orders = 0
    @total_refunded_meals = 0
    @total_refunded_amount = 0.0

    orders.each do |order|
      is_gift_order = false

      order_type = order['customAttributes'].find { |a| a['key'] == 'Type Of Order' }
      order_zone = order['customAttributes'].find { |a| a['key'] == 'Location Name' }

      unless order_type
        puts "order #{order['id']} no delivery type"
      end
      if order['closedAt'] || order['cancelledAt']
        puts "order #{order['id']} close"
      end
      next if order['closedAt']
      next if order['cancelledAt']
      next unless order_type
      next if order['tags'].include?('internal-order')

      if order_type['value'] != 'Store Pickup'
        unless order_zone
          puts "order #{order['id']} doesn't have zone"
          next
        end
      end

      if @report_territory == 'NJ'
        if order_type['value'] != 'Store Pickup'
          if order_zone['value'] != @report_territory
            puts "pass pickup order #{order['id']}"
            next
          end
        end
      end

      if @report_territory == 'GA'
        if order_type['value'] == 'Store Pickup'
          puts "pass pickup order #{order['id']}"
          next
        else
          if order_zone['value'] != @report_territory
            puts "pass pickup order #{order['id']}"
            next
          end
        end
      end

      @total_credit_discount += order['totalDiscountsSet']['shopMoney']['amount'].to_f

      order['refunds'].each do |refund|
        @total_refunded_amount += refund['totalRefundedSet']['shopMoney']['amount'].to_f
        refund['refundLineItems']['edges'].each do |item|
          if item['node']['lineItem']['product']['vendor'] == 'Eat Clean Bro LLC'
            @total_refunded_meals += item['node']['quantity']
          end
        end
      end

      if order['refunds'].length > 0
        @total_refunded_orders += 1
      end

      order['transactions'].each do |transaction|
        if transaction['kind'].downcase != 'refund'
          if transaction['gateway'] == 'gift_card'
            @total_gift_collected += transaction['amountSet']['shopMoney']['amount'].to_f
            @total_giftcard_discount +=  transaction['amountSet']['shopMoney']['amount'].to_f
            if transaction['amountSet']['shopMoney']['amount'].to_f == order['currentSubtotalPriceSet']['shopMoney']['amount']
              is_gift_order = true
            end
          else
            @total_credit_collected += transaction['amountSet']['shopMoney']['amount'].to_f
          end
        end
      end

      order['lineItems']['edges'].each do |line_item|
        if line_item['node']['vendor'] == 'Eat Clean Bro LLC'
          @total_meals += line_item['node']['quantity']
          if is_gift_order
            @total_gift_meals += line_item['node']['quantity']
          else
            @total_credit_meals += line_item['node']['quantity']
          end
        end
      end

      if order_type['value'] == 'Local Delivery'
        @total_delivery_fees += 12.99
        @total_delivery_count += 1
      end

      if order_type['value'] == 'Store Pickup'
        @total_pickup_count += 1
      end

      if order_type['value'] == 'Shipping'
        @total_shipping_count += 1
      end

      @total_tax_collected += order['currentTotalTaxSet']['shopMoney']['amount'].to_f

      if order['totalTipReceivedSet']['shopMoney']['amount'].to_f > 0
        @total_tip_count += 1
        @total_tip_received += order['totalTipReceivedSet']['shopMoney']['amount'].to_f
      end

      @total_product_revenue += order['subtotalPriceSet']['shopMoney']['amount'].to_f
    end

    @total_collected = @total_credit_collected + @total_gift_collected
    @total_discount = @total_credit_discount + @total_giftcard_discount

    @parsed_report_date = Date.parse(report_date).strftime("%A, %B %d, %Y")

    content = ReportsController.render(
      template: 'reports/template_summary',
      layout: args[:params]['layout'] ? args[:params]['layout'] : 'application',
      assigns: {
        report_territory: @report_territory,
        parsed_report_date: @parsed_report_date,
        total_meals: @total_meals,
        total_gift_meals: @total_gift_meals,
        total_credit_meals: @total_credit_meals,
        total_delivery_fees: @total_delivery_fees,
        total_tax_collected: @total_tax_collected,
        total_tip_received: @total_tip_received,
        total_tip_count: @total_tip_count,
        total_product_revenue: @total_product_revenue,
        total_delivery_count: @total_delivery_count,
        total_pickup_count: @total_pickup_count,
        total_shipping_count: @total_shipping_count,
        total_credit_discount: @total_credit_discount,
        total_giftcard_discount: @total_giftcard_discount,
        total_discount: @total_discount,
        total_credit_collected: @total_credit_collected,
        total_gift_collected: @total_gift_collected,
        total_collected: @total_collected,
        total_refunded_orders: @total_refunded_orders,
        total_refunded_meals: @total_refunded_meals,
        total_refunded_amount: @total_refunded_amount,
      }
    )

    report = Report.create(
      :template => content,
      :generate_mode => 'summary',
      :location => args[:params]['delivery_zone'],
      :delivery_date => args[:params]['report_date'],
    )

    if args[:params]['type'] == 'daily'
      args[:email].split(',').each do |email_address|
        UserNotifierMailer.send_report_email_with_attachment(email_address, content).deliver
      end
    else
      UserNotifierMailer.send_report_email(args[:email], report).deliver
    end
  end
end
