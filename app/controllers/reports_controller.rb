class ReportsController < ApplicationController
  before_action :verify_authenticity_token
  before_action :authenticate_user!
  skip_before_action :verify_authenticity_token, :only => :create

  def export
    respond_to do |format|
      format.html
      format.pdf do
        render pdf: "file_name", template: "invoices/show", formats: [:html]
      end
    end
  end

  def index
  end

  def show
    @report = Report.find(params[:id])
  end

  def generate_ups
    GenerateReportJob.perform_now({
      email: current_user.email,
      type: 'ups',
      params: request.params
    })
  end

  def generate_pickup
    GenerateReportJob.perform_now({
      email: current_user.email,
      type: 'pickup',
      params: request.params
    })
  end

  def generate_delivery
    GenerateReportJob.perform_now({
      email: current_user.email,
      type: 'delivery',
      params: request.params
    })
  end

  def generate_summary
    GenerateReportJob.perform_now({
      email: current_user.email,
      type: 'summary',
      params: request.params
    })
  end

  def generate_jobs
    Sidekiq::Cron::Job.create(name: 'Daily Report Worker - every 1sec', cron: '*/1 * * *', class: 'DailyReportWorker')
  end
end
