require 'open-uri'

class WorkWaveService
  def initialize
  end

  # route endpoints
  def list_routes(territory_id, date)
    sub_scope = "toa/routes?date=#{date}"
    url = api_url('get', 'territories', territory_id, sub_scope)
    get(url)
  end

  private

  def base_url
    "https://wwrm.workwave.com/api/v1"
  end

  def api_url(type, scope, id = false, sub_scope = false)
    case type
    when 'get', 'put', 'delete'
      sub_scope ? "#{base_url}/#{scope}/#{id}/#{sub_scope}" : "#{base_url}/#{scope}/#{id}"
    end
  end

  def get(url)
    begin
      response = RestClient.get url, {
        'X-WorkWave-Key' => ENV['WORK_WAVE_API_KEY'],
        'Content-Type' => 'application/json',
        'Accept' => 'application/json',
        'Host' => 'wwrm.workwave.com',
      }

      return JSON.parse(response)
    rescue RestClient::ExceptionWithResponse => e
      http_body = JSON.parse(e.http_body)
      meaningful_error_message = http_body['message'].nil? ? e.message : http_body['message']
    end
  end
end
