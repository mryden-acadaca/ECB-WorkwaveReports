class UserNotifierMailer < ApplicationMailer
  default :from => 'info@eatcleanbro.com'

  # send a signup email to the user, pass in the user object that   contains the user's email address
  def send_report_email(email, report)
    @report = report

    mail(
      :to => email,
      :subject => 'Your report is ready'
    )
  end

  def send_report_email_with_attachment(email, content)
    kit = PDFKit.new(content)
    attachments['report.pdf'] = kit.to_pdf
    puts email
    mail(
      :to => email,
      :subject => 'Your report is ready'
    )
  end
end
