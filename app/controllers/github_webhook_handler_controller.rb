# Controller for handling GitHub webhooks.
class GithubWebhookHandlerController < ApplicationController
  skip_before_action :verify_authenticity_token

  def handle_webhook
    payload_raw = request.body.read
    payload = JSON.parse(payload_raw)
    event_type = request.headers['X-GitHub-Event']
    installation_id = payload.dig('installation', 'id')

    return unless event_type == 'pull_request'

    handle_pull_request(payload['pull_request'], installation_id)
  end

  private

  def handle_pull_request(pull_request, installation_id)
    pull_request_number = pull_request['number']
    owner = pull_request.dig('head', 'repo', 'owner', 'login')
    repo = pull_request.dig('head', 'repo', 'name')

    access_token = fetch_access_token(installation_id)
    return unless access_token

    client = Octokit::Client.new(bearer_token: access_token)
    client.update_pull_request("#{owner}/#{repo}", pull_request_number, title: 'Updated Title')
  end

  def fetch_access_token(installation_id)
    response = Faraday.post do |req|
      req.url "https://api.github.com/app/installations/#{installation_id}/access_tokens"
      req.headers['Accept'] = 'application/vnd.github+json'
      req.headers['Authorization'] = "Bearer #{generate_jwt}"
      req.headers['X-GitHub-Api-Version'] = '2022-11-28'
    end

    JSON.parse(response.body)['token'] if response.success?
  rescue StandardError => e
    puts "Error fetching access token: #{e.message}"
    nil
  end

  def generate_jwt
    private_pem = File.read(Rails.application.secrets.github_app_private_key_pem)
    private_key = OpenSSL::PKey::RSA.new(private_pem)

    payload = {
      iss: Rails.application.secrets.github_app_id,
      iat: Time.now.to_i,
      exp: Time.now.to_i + (10 * 60)
    }

    JWT.encode(payload, private_key, 'RS256')
  end
end
