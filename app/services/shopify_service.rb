class ShopifyService
  def initialize
  end

  def delete_order(order_id)
    url = "https://#{ENV['SHOPIFY_DOMAIN']}/admin/api/#{ENV['SHOPIFY_API_VERSION']}/orders/#{order_id}.json"
    res = delete(url)
    puts res
    puts "order #{order_id} has been deleted"
  end

  def get_order_ids(params = false)
    orders = []

    session = ShopifyAPI::Auth::Session.new(
      shop: ENV['SHOPIFY_DOMAIN'],
      access_token: ENV['SHOPIFY_ACCESS_TOKEN']
    )
    client = ShopifyAPI::Clients::Graphql::Admin.new(
      session: session
    )

    query = <<~QUERY
      query {
        orders(first: 200, query: "tag:#{params[:tag]}") {
          edges {
            node {
              id
              processedAt
            }
          }
          pageInfo {
            hasNextPage
            endCursor
          }
        }
      }
    QUERY

    response = client.query(query: query)
    orders += response.body['data']['orders']['edges'] if response.body['data']['orders'].present?

    count = 0

    loop do
      count += 1
      break if count > 6
      break unless response.body['data']['orders']['pageInfo']['hasNextPage']
      query = <<~QUERY
        query ($numOrders: Int!, $cursor: String) {
          orders(first: $numOrders, after: $cursor, query: "tag:#{params[:tag]}") {
            edges {
              node {
                id
                processedAt
              }
            }
            pageInfo {
              hasNextPage
              endCursor
            }
          }
        }
      QUERY
      response = client.query(query: query, variables: {
          numOrders: 200,
          cursor: response.body['data']['orders']['pageInfo']['endCursor']
      })

      orders += response.body['data']['orders']['edges'] if response.body['data']['orders'].present?
    end
    orders
  end

  def list_channels_graphql()
    orders = []

    session = ShopifyAPI::Auth::Session.new(
      shop: ENV['SHOPIFY_DOMAIN'],
      access_token: ENV['SHOPIFY_ACCESS_TOKEN']
    )
    client = ShopifyAPI::Clients::Graphql::Admin.new(
      session: session
    )

    query = <<~QUERY
      query {
        channels (first: 50) {
          edges {
            node {
              id
              name
            }
          }
        }
      }
    QUERY

    response = client.query(query: query)
  end

  def list_orders_graphql()
    orders = []

    session = ShopifyAPI::Auth::Session.new(
      shop: ENV['SHOPIFY_DOMAIN'],
      access_token: ENV['SHOPIFY_ACCESS_TOKEN']
    )
    client = ShopifyAPI::Clients::Graphql::Admin.new(
      session: session
    )

    query = <<~QUERY
      query {
        orders(first: 200, query: "channel_id:580111") {
          edges {
            node {
              id
              processedAt
            }
          }
          pageInfo {
            hasNextPage
            endCursor
          }
        }
      }
    QUERY

    response = client.query(query: query)

    count = 0
    loop do
      count += 1
      break if count > 30
      orders += response.body['data']['orders']['edges'] if response.body['data']['orders'].present?
      break unless response.body['data']['orders']['pageInfo']['hasNextPage']
      query = <<~QUERY
        query ($numOrders: Int!, $cursor: String) {
          orders(first: $numOrders, after: $cursor, query: "channel_id:'580111'") {
            edges {
              node {
                id
                processedAt
              }
            }
            pageInfo {
              hasNextPage
              endCursor
            }
          }
        }
      QUERY
      response = client.query(query: query, variables: {
          numOrders: 200,
          cursor: response.body['data']['orders']['pageInfo']['endCursor']
      })
    end
  end

  def list_day_orders(params = false)
    str = ''

    params[:ids].each_with_index do |id, index|
      if index == 0
        str += '"' + id + '"'
      else
        str += "," + '"' + id + '"'
      end
    end

    session = ShopifyAPI::Auth::Session.new(
      shop: ENV['SHOPIFY_DOMAIN'],
      access_token: ENV['SHOPIFY_ACCESS_TOKEN']
    )
    client = ShopifyAPI::Clients::Graphql::Admin.new(
      session: session
    )

    query = <<~QUERY
      query {
        nodes(ids: [#{str}]) {
          id
          ... on Order {
            id
            totalPrice
            note
            cancelledAt
            closedAt
            paymentGatewayNames
            tags
            currentTotalTaxSet {
              shopMoney {
                amount
              }
            }
            subtotalPriceSet {
              shopMoney {
                amount
              }
            }
            currentSubtotalPriceSet {
              shopMoney {
                amount
              }
            }
            totalTipReceivedSet {
              shopMoney {
                amount
              }
            }
            totalDiscountsSet {
              shopMoney {
                amount
              }
            }
            currentSubtotalPriceSet {
              shopMoney {
                amount
              }
            }
            customAttributes {
              key
              value
            }
            transactions(first: 25) {
             kind
             gateway
             amountSet {
               shopMoney {
                 amount
               }
             }
            }
            refunds(first: 25) {
              refundLineItems(first: 10) {
                edges {
                  node {
                    quantity
                    lineItem {
                      product {
                        vendor
                      }
                    }
                  }
                }
              }
              totalRefundedSet {
                shopMoney {
                  amount
                }
              }
            }
            lineItems (first: 100) {
              edges {
                node {
                  title
                  quantity
                  vendor
                }
              }
            }
          }
        }
      }
    QUERY
    response = client.query(query: query)
    return response
  end

  def get_order_transaction(params)
    url = "https://#{ENV['SHOPIFY_DOMAIN']}/admin/api/#{ENV['SHOPIFY_API_VERSION']}/orders/#{params[:order_id]}/transactions.json"
    transactions = get(url)
    transactions
  end

  def list_orders(params = false)
    orders = []
    session = ShopifyAPI::Auth::Session.new(
      shop: ENV['SHOPIFY_DOMAIN'],
      access_token: ENV['SHOPIFY_ACCESS_TOKEN']
    )
    client = ShopifyAPI::Clients::Rest::Admin.new(session: session)

    response = client.get(path: "orders", query: {
      limit: 100,
      tag: params[:tag],
      status: 'any'
    })

    loop do
      orders.push(*response.body['orders']) if response.body['orders'].present?
      break unless response.next_page_info
      response = client.get(path: "orders", query: {
        limit: 100, page_info: response.next_page_info,
      })
    end

    orders
  end

  def add_note_attributes()
    session = ShopifyAPI::Auth::Session.new(
      shop: ENV['SHOPIFY_DOMAIN'],
      access_token: ENV['SHOPIFY_ACCESS_TOKEN']
    )
    client = ShopifyAPI::Clients::Graphql::Admin.new(
      session: session
    )
    query = <<~QUERY
      mutation updateOrderNoteAttributes($input: OrderInput!) {
        orderUpdate(input: $input) {
          order {
            id
            customAttributes {
              key
              value
            }
          }
          userErrors {
            message
            field
          }
        }
      }
    QUERY
    variables = {
      "input": {
        "customAttributes": [
          {
            "key" => "Type Of Order",
            "value" => ""
          },
          {
            "key" => "Shipping Delivery Date",
            "value" => ""
          },
          {
            "key" => "Shipping Delivery Day",
            "value" => ""
          },
          {
            "key" => "Shipping Delivery Time",
            "value" => ""
          },
          {
            "key" => "Pickup Location",
            "value" => ""
          },
          {
            "key" => "Pickup Date",
            "value" => ""
          },
          {
            "key" => "Pickup Day",
            "value" => ""
          },
          {
            "key" => "Pickup Address",
            "value" => ""
          },
          {
            "key" => "LocationId",
            "value" => ""
          },
          {
            "key" => "zip",
            "value" => ""
          },
          {
            "key" => "Delivery Date",
            "value" => ""
          },
          {
            "key" => "Delivery Day",
            "value" => ""
          },
          {
            "key" => "Location Name",
            "value" => ""
          },
          {
            "key" => "Delivery Type",
            "value" => ""
          },
          {
            "key" => "WareHouse Location",
            "value" => ""
          }
        ],
        "id": "gid://shopify/Order/5384800305459"
      }
    }
    response = client.query(query: query, variables: variables)
    puts response.body
  end

  def add_ups_attributes(order_id, zip)
    session = ShopifyAPI::Auth::Session.new(
      shop: ENV['SHOPIFY_DOMAIN'],
      access_token: ENV['SHOPIFY_ACCESS_TOKEN']
    )
    client = ShopifyAPI::Clients::Graphql::Admin.new(
      session: session
    )
    query = <<~QUERY
      mutation updateOrderNoteAttributes($input: OrderInput!) {
        orderUpdate(input: $input) {
          order {
            id
            customAttributes {
              key
              value
            }
          }
          userErrors {
            message
            field
          }
        }
      }
    QUERY
    variables = {
      "input": {
        "customAttributes": [
          {
            "key" => "Type Of Order",
            "value" => "Shipping"
          },
          {
            "key" => "Shipping Delivery Date",
            "value" => ""
          },
          {
            "key" => "Shipping Delivery Day",
            "value" => ""
          },
          {
            "key" => "Shipping Delivery Time",
            "value" => ""
          }
        ],
        "id": "gid://shopify/Order/#{order_id}"
      }
    }
    response = client.query(query: query, variables: variables)
  end

  def add_delivery_attributes(order_id, zip, location_name)
    session = ShopifyAPI::Auth::Session.new(
      shop: ENV['SHOPIFY_DOMAIN'],
      access_token: ENV['SHOPIFY_ACCESS_TOKEN']
    )
    client = ShopifyAPI::Clients::Graphql::Admin.new(
      session: session
    )
    query = <<~QUERY
      mutation updateOrderNoteAttributes($input: OrderInput!) {
        orderUpdate(input: $input) {
          order {
            id
            customAttributes {
              key
              value
            }
          }
          userErrors {
            message
            field
          }
        }
      }
    QUERY
    variables = {
      "input": {
        "customAttributes": [
          {
            "key" => "Type Of Order",
            "value" => "Local Delivery"
          },
          {
            "key" => "zip",
            "value" => zip
          },
          {
            "key" => "Delivery Date",
            "value" => ""
          },
          {
            "key" => "Delivery Day",
            "value" => ""
          },
          {
            "key" => "Location Name",
            "value" => location_name
          },
          {
            "key" => "Location Id",
            "value" => ""
          },
          {
            "key" => "Delivery Type",
            "value" => ""
          },
          {
            "key" => "WareHouse Location",
            "value" => ""
          }
        ],
        "id": "gid://shopify/Order/#{order_id}"
      }
    }
    client.query(query: query, variables: variables)
  end

  def add_pickup_attributes(order_id, zip)
    session = ShopifyAPI::Auth::Session.new(
      shop: ENV['SHOPIFY_DOMAIN'],
      access_token: ENV['SHOPIFY_ACCESS_TOKEN']
    )
    client = ShopifyAPI::Clients::Graphql::Admin.new(
      session: session
    )
    query = <<~QUERY
      mutation updateOrderNoteAttributes($input: OrderInput!) {
        orderUpdate(input: $input) {
          order {
            id
            customAttributes {
              key
              value
            }
          }
          userErrors {
            message
            field
          }
        }
      }
    QUERY
    variables = {
      "input": {
        "customAttributes": [
          {
            "key" => "Type Of Order",
            "value" => "Store Pickup"
          },
          {
            "key" => "Pickup Location",
            "value" => ""
          },
          {
            "key" => "Pickup Date",
            "value" => ""
          },
          {
            "key" => "Pickup Day",
            "value" => ""
          },
          {
            "key" => "Pickup Address",
            "value" => ""
          },
          {
            "key" => "LocationId",
            "value" => ""
          },
        ],
        "id": "gid://shopify/Order/#{order_id}"
      }
    }
    client.query(query: query, variables: variables)
  end

  def list_orders_by_ids(params = false)
    formatted_ids = []
    str = ''

    params[:ids].each_with_index do |id, index|
      formatted_id = "gid://shopify/Order/#{id}"
      formatted_ids.push(formatted_id)
      if index == 0
        str += '"' + formatted_id.to_s + '"'
      else
        str += "," + '"' + formatted_id.to_s + '"'
      end
    end

    session = ShopifyAPI::Auth::Session.new(
      shop: ENV['SHOPIFY_DOMAIN'],
      access_token: ENV['SHOPIFY_ACCESS_TOKEN']
    )
    client = ShopifyAPI::Clients::Graphql::Admin.new(
      session: session
    )

    query = <<~QUERY
      query {
        nodes(ids: [#{str}]) {
          id
          ... on Order {
            id
            totalPrice
            note
            paymentGatewayNames
            customAttributes {
              key
              value
            }
            shippingAddress {
              id
              address1
              address2
              city
              zip
              province
            }
            customer {
              firstName
              lastName
              phone
            }
            lineItems (first: 100) {
              edges {
                node {
                  title
                  quantity
                  vendor
                  variantTitle
                }
              }
            }
          }
        }
      }
    QUERY
    response = client.query(query: query)
  end

  def test(order_id)
    session = ShopifyAPI::Auth::Session.new(
      shop: ENV['SHOPIFY_DOMAIN'],
      access_token: ENV['SHOPIFY_ACCESS_TOKEN']
    )
    client = ShopifyAPI::Clients::Graphql::Admin.new(
      session: session
    )

    count = 0
    loop do
      count = count + 1
      break if count > 80
      query = <<~QUERY
        mutation DraftOrderCreateFromOrder($orderId: ID!) {
          draftOrderCreateFromOrder(orderId: $orderId) {
            draftOrder {
              id
            }
            userErrors {
              field
              message
            }
          }
        }
      QUERY
      variables = {
        "orderId": "gid://shopify/Order/#{order_id}"
      }
      response = client.query(query: query, variables: variables)
      id = response.body['data']['draftOrderCreateFromOrder']['draftOrder']['id']
      puts "draft order #{count} number: #{id} has been created"

      query = <<~QUERY
        mutation draftOrderComplete($id: ID!) {
          draftOrderComplete(id: $id) {
            draftOrder {
              id
              order {
                id
              }
            }
          }
        }
      QUERY
      variables = {
        "id": id
      }
      response = client.query(query: query, variables: variables)
      puts "order #{id} has been created"
    end
  end

  def get_order(id)
    url = "https://#{ENV['SHOPIFY_DOMAIN']}/admin/api/#{ENV['SHOPIFY_API_VERSION']}/orders/#{id}.json"
    get(url)
  end

  def update_order(id, payload)
    url = "https://#{ENV['SHOPIFY_DOMAIN']}/admin/api/#{ENV['SHOPIFY_API_VERSION']}/orders/#{id}.json"
    put(url, payload)
  end

  private

  def base_url
    "https://#{ENV['SHOPIFY_DOMAIN']}/admin/api/#{ENV['SHOPIFY_API_VERSION']}/graphql.json"
  end

  def api_url(type, scope, id = false, sub_scope = false, params = false)
    url = base_url

    case type
    when 'list', 'post'
      url = sub_scope ? "#{base_url}/#{scope}/#{id}/#{sub_scope}.json" : "#{base_url}/#{scope}.json"
    when 'get', 'put', 'delete'
      url = sub_scope ? "#{base_url}/#{scope}/#{id}/#{sub_scope}.json" : "#{base_url}/#{scope}/#{id}.json"
    end

    if params
      params.each do |key, value|
        if url.include? "?"
          url = "#{url}&#{key.to_s}=#{value}"
        else
          url = "#{url}?#{key.to_s}=#{value}"
        end
      end
    end

    url
  end

  def get(url)
    begin
      response = RestClient.get url, {
        'X-Shopify-Access-Token' => ENV['SHOPIFY_ACCESS_TOKEN'],
        'Content-Type' => 'application/json'
      }

      return JSON.parse(response)
    rescue RestClient::ExceptionWithResponse => e
      http_body = JSON.parse(e.http_body)
      meaningful_error_message = http_body['message'].nil? ? e.message : http_body['message']
    end
  end

  def post(url, body)
    begin
      response = RestClient.post url, body.to_json, {
        'X-Shopify-Access-Token' => ENV['SHOPIFY_ACCESS_TOKEN'],
        'Content-Type' => 'application/json'
      }

      return JSON.parse(response)
    rescue RestClient::ExceptionWithResponse => e
      http_body = JSON.parse(e.http_body)
      meaningful_error_message = http_body['message'].nil? ? e.message : http_body['message']
    end
  end

  def put(url, body)
    begin
      response = RestClient.put url, body.to_json, {
        'X-Shopify-Access-Token' => ENV['SHOPIFY_ACCESS_TOKEN'],
        'Content-Type' => 'application/json'
      }

      return JSON.parse(response)
    rescue RestClient::ExceptionWithResponse => e
      http_body = JSON.parse(e.http_body)
      meaningful_error_message = http_body['message'].nil? ? e.message : http_body['message']
    end
  end

  def delete(url)
    begin
      response = RestClient.delete url, {
        'X-Shopify-Access-Token' => ENV['SHOPIFY_ACCESS_TOKEN'],
        'Content-Type' => 'application/json'
      }

      return JSON.parse(response)
    rescue RestClient::ExceptionWithResponse => e
      http_body = JSON.parse(e.http_body)
      meaningful_error_message = http_body['message'].nil? ? e.message : http_body['message']
    end
  end
end
