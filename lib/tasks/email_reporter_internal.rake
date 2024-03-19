desc "send report to locals"
task send_report_internal: :environment do
  puts "Getting ready for sending daily report to admins..."

  date = Date.yesterday.strftime("%Y%m%d")
  custom_params = {}

  day = Date.today.strftime('%A')

  if ['Sunday', 'Monday', 'Tuesday', 'Thursday'].include?(day)
    # GA report
    custom_params['report_date'] = date
    custom_params['delivery_zone'] = '5,6'
    custom_params['type'] = 'daily'
    custom_params['layout'] = 'custom'
    GenerateReportJob.perform_now({
      email: ENV['REPORT_EMAILS'],
      type: 'summary',
      params: custom_params
    })

    # NJ report
    custom_params['report_date'] = date
    custom_params['delivery_zone'] = '1,2,4,10'
    custom_params['type'] = 'daily'
    custom_params['layout'] = 'custom'
    GenerateReportJob.perform_now({
      email: ENV['REPORT_EMAILS'],
      type: 'summary',
      params: custom_params
    })

    puts "Daily report sent!"
  end
end
