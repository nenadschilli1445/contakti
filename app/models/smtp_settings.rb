class SmtpSettings < ActiveRecord::Base
  REQUIRED_FIELDS = %i[server_name port]
  REQUIRED_FIELDS.push(*%i[user_name password auth_method]) unless Rails.env.development?

  AUTH_METHODS = %w[login NTLM]
  AUTH_METHODS.push('plain') if Rails.env.development? # @todo should be in other envs too?

  has_many :service_channels
  belongs_to :company

  validates :auth_method, inclusion: { in: AUTH_METHODS }

  validates :port, presence: true
  before_update :remove_tokens
  #
  def remove_tokens
    return if use_365_mailer_change.nil?

    if use_365_mailer_change.first == true and use_365_mailer_change.second == false
      self.microsoft_token = nil
      self.ms_refresh_token = nil
    end
  end

  def get_auth_method
    return :login if auth_method.blank?
    auth_method.downcase.to_sym
  end

  def all_required_data_fills?
    REQUIRED_FIELDS.all? do |key|
      __send__(key).present?
    end
  end
end

