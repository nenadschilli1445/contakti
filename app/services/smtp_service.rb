require 'mail'
require 'net/smtp'
require 'ntlm/smtp'
require 'base64'

class SmtpService
  def initialize(message)
    @message = message
  end

  def send_email
    if @message.task.media_channel.smtp_settings.use_365_mailer
      include_attachments
      send_mail_through_microsoft_service
    else
      email.delivery_handler = self
      include_attachments
      email.deliver
    end
  end

  def include_attachments
    @message.attachments.each do |attachment|
#     mail.add_file(:filename => a.original_filename, :content => a.tempfile.read)
     email.add_file(filename: attachment.file_name, content: attachment.file.read)

#      email.attachments[attachment.file_name] = {
#        content: attachment.file.read
#      }
    end
  end

  def strip_html(html)
    body_parts = []

    Nokogiri::HTML(html).traverse do |node|
      if node.text? and (content = node.content ? node.content.strip : nil).present?
        body_parts << content
      elsif node.name == 'a' and (href = node.attr('href'))
        body_parts << href
      end
    end

    body_parts.join "\r\n"
  rescue
    ActionView::Base.full_sanitizer.sanitize html
  end

  def email
    @email ||= begin
      real_email = ::Mail::Message.new
      real_email.charset = 'UTF-8'
      real_email.content_transfer_encoding = '8bit'
      real_email.subject = @message.title
      real_email.from = @message.from
      real_email.to = @message.to
      real_email.cc = @message.cc if @message.cc.present?
      real_email.bcc = @message.bcc if @message.bcc.present?

      real_email.part(content_type: 'multipart/alternative') do |rep|
        rep.part(content_type: 'text/html') do |p|
          p.content_type 'text/html'
          p.body = @message.description
        end

        rep.part(content_type: 'text/plain') do |p|
          p.content_type 'text/plain'
          p.body = strip_html @message.description
        end
      end

#      html_part = Mail::Part.new
#      html_part.body = @message.description
#      html_part.content_type = 'text/html'
#      real_email.html_part = html_part

#      text_part = Mail::Part.new
#      text_part.body = strip_html @message.description
#      real_email.text_part = text_part

      real_email
    end
  end

  def settings
    if Rails.env.development? && false
      # From vagrant to host IP => Papercut (fake SMTP server)
      @settings = ::SmtpSettings.new(server_name: '10.0.2.2', port: 25, user_name: '', password: '', auth_method: 'login')
    end

    p 'SmtpService: find smtp settings'
    if !!(@message.try(:task).try(:service_channel).try(:web_form_media_channel).try(:smtp_settings).try(:user_name) && @message.try(:task) && @message.task.media_channel.web_form?)
      p 'SmtpService: found web form smtp settings'
      @settings ||= @message.task.service_channel.web_form_media_channel.smtp_settings
    elsif @message.task.use_assigned_user_email_settings && @message.task.agent && @message.task.agent.smtp_settings
      p 'SmtpService: found user smtp settings'
      @settings ||= @message.task.agent.smtp_settings
    else
      p 'SmtpService: found service channel smtp settings'
      @settings ||= @message.task.service_channel.email_media_channel.smtp_settings
    end
  end

  def settings=(settings)
    @settings = settings
  end

  def smtp_settings
    if Rails.env.development? && false
      # From vagrant to host IP => Papercut (fake SMTP server), disable authentication
      @smtp_settings = {
          address: '10.0.2.2',
          port: 25
      }
    end

    if settings.class.name == 'SmtpSettings' && settings.use_contakti_smtp?
      @smtp_settings = Settings.smtp
    else
      tls = nil
      enable_starttls_auto = nil
      if settings.port.to_i == 465
        tls = true if settings.use_ssl?
      elsif settings.port.to_i == 587
        enable_starttls_auto = true if settings.use_ssl?
      end

      domain = settings.user_name.include?('@') ? settings.user_name.partition('@').last : 'localhost'

      if settings.server_name == "smtp.office365.com" || settings.server_name == "smtp-mail.outlook.com"
        ssl = false
      else
        ssl = settings.use_ssl?
      end
      @smtp_settings ||= {
        address:               settings.server_name,
        port:                  settings.port,
        domain:                domain,
        user_name:             settings.user_name,
        password:              settings.password,
        authentication:        settings.get_auth_method,
        enable_starttls_auto:  enable_starttls_auto,
        ssl:                   ssl,
        tls:                   tls,
      }
    end

    p @smtp_settings

    @smtp_settings
  end

  def delivery_handler
    @delivery_handler ||= ::Mail::SMTP.new(smtp_settings)
  end

  def deliver_mail(mail)
    delivery_handler.deliver!(mail)
  end

  def send_mail_through_microsoft_service
     SmtpService.test({ "use_365_mailer" => "1", "media_channel_id" => @message.task.media_channel.id })
    smtp_setting = @message.task.media_channel.smtp_settings
    token = "Bearer #{smtp_setting.microsoft_token}"
    subject = @message.title
    ccRecipients = [{ "emailAddress":
                         {"address": @message.settings["cc"][0]}
                     }] if @message.settings["cc"].present?
    recepcients = @message.to.split(',').map do |address|
      {
        "emailAddress": {
          "address": address.strip
        }
      }
    end
    file_attachments = @message.attachments.map do |attachment|
       data = attachment.file.read
       encoded = Base64.encode64(data)
       content_bytes = encoded.gsub(/\n/,"")
       {
         "@odata.type": "#microsoft.graph.fileAttachment",
         "name": attachment.file_name,
         "contentType": attachment.content_type,
         "contentBytes": content_bytes
       }
     end

     url = "https://graph.microsoft.com/v1.0/me/sendMail"
     body = {
      "message": {
        "subject": "#{subject}",
        "body": {
          "contentType": "HTML",
          "content": "#{@message.description}"
        },
        "toRecipients": recepcients,
        "attachments":  file_attachments
      },
      "saveToSentItems": "false"
    }
    body[:message][:ccRecipients] = ccRecipients if ccRecipients.present?
    headers = { 'Content-Type' => 'application/json', 'Authorization' => token }
    response = HTTParty.post(url, body: body.to_json, headers: headers)
    puts "--------------------------------------------"
    puts response
  end

  class << self
    def test(settings)
      if settings["use_365_mailer"] == "1" || settings["use_365_mailer"] == true
        channel = MediaChannel.find(settings["media_channel_id"])
        smtp_setting = channel.smtp_settings
        refresh_token = smtp_setting.ms_refresh_token
        url = "https://login.microsoftonline.com/#{ENV["AZURE_CREDENTIAL"]}/oauth2/v2.0/token"
        options = {
          body: {
            "client_id": ENV["CLIENT_ID"],
            "grant_type": "refresh_token",
            "scope": "https://graph.microsoft.com/.default",
            "refresh_token": refresh_token,
            "client_secret": ENV["CLIENT_SECRET"]
          },
          headers: {
            'Content-Type' => 'application/x-www-form-urlencoded'
          }
        }
        token = HTTParty.post(url, options)
        if token.response.present?
          smtp_setting.update(
            microsoft_token: token["access_token"],
            ms_refresh_token: token["refresh_token"],
            expire_in: token["ext_expires_in"],
            token_updated_at: DateTime.now
          )
          return { success: true }
        else
          return { success: false }
        end
      else
        use_ssl = settings[:use_ssl] == '1' || settings[:use_ssl] == true
        username = settings[:user_name].blank? ? nil : settings[:user_name]
        password = settings[:password].blank? ? nil : settings[:password]
        smtp = ::Net::SMTP.new(settings[:server_name], settings[:port])
        smtp.read_timeout = 5 # in seconds
        if settings[:port].to_i == 465
          smtp.enable_tls() if use_ssl
        elsif settings[:port].to_i == 587
          smtp.enable_starttls() if use_ssl
        end
        helo_domain = settings[:user_name].include?('@') ? settings[:user_name].partition('@').last : 'localhost'
        smtp.start(
          helo_domain, username, password, :login
        )
        smtp.finish
        return { success: true }
      end
    rescue => ex
      ::Rails.logger.info "Exception on establishing connection with SMTP server: #{ex.message}"
      { success: false, message: ex.message }
    end
  end
end

