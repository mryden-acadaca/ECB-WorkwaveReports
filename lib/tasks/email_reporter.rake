desc "send report to admins"
task send_report: :environment do
  puts "Getting ready for sending daily report to admins..."

  date = Date.yesterday.strftime("%Y%m%d")
  custom_params = {}

  # GA report
  custom_params['report_date'] = date
  custom_params['delivery_zone'] = '5,6'
  custom_params['type'] = 'daily'
  custom_params['layout'] = 'custom'
  GenerateReportJob.perform_now({
    email: ENV['REPORT_DEV_EMAILS'],
    type: 'summary',
    params: custom_params
  })

  # NJ report
  custom_params['report_date'] = date
  custom_params['delivery_zone'] = '1,2,4,10'
  custom_params['type'] = 'daily'
  custom_params['layout'] = 'custom'
  GenerateReportJob.perform_now({
    email: ENV['REPORT_DEV_EMAILS'],
    type: 'summary',
    params: custom_params
  })

  puts "Daily report sent!"
end
