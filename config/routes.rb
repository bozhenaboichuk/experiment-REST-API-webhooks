Rails.application.routes.draw do
  post '/', to: 'github_webhook_handler#handle_webhook'
end
