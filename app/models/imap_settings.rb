class ImapSettings < ActiveRecord::Base
  if Rails.env.development?
    REQUIRED_FIELDS = %i[server_name port]
  else
    REQUIRED_FIELDS = %i[server_name user_name password port]
  end

  has_one :media_channel
  belongs_to :company

  before_update :remove_tokens
  #
  def remove_tokens
    return if use_365_mailer_change.nil?

    if use_365_mailer_change.first == true and use_365_mailer_change.second == false
      self.microsoft_token = nil
      self.ms_refresh_token = nil
    end
  end

  def from
    if self.from_full_name.present? && self.from_email.present?
      "#{self.from_full_name} <#{self.from_email}>"
    else
      self.from_email.present? ? self.from_email : self.user_name
    end
  end

  def all_required_data_fills?
    return true if use_365_mailer

    REQUIRED_FIELDS.all? do |key|
      __send__(key).present?
    end
  end
end

