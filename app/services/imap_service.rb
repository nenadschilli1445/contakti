require 'net/imap'
require 'mail'
require 'attachment_string_io'
require 'charlock_holmes/string' if Rails.env.production? || Rails.env.staging?

class ImapService

  def initialize(imap_settings)
    @settings = imap_settings
    unless imap_settings.use_365_mailer
      @imap     = Net::IMAP.new(@settings.server_name, @settings.port, @settings.use_ssl)
      @imap.login(@settings.user_name, @settings.password)
    end
  end

  def disconnect
    @imap.disconnect unless !@imap || @imap.disconnected?
  end

  def mark_email_as_read(message_uid)
    return if @imap.nil?

    @imap.select('INBOX')
    @imap.uid_store(message_uid, "+FLAGS", [:Seen])
  end

  def fetch_from_imap(media_channel, start_date = nil, keepalive = false)
    messages = ::Message.in_media_channel(media_channel.id).where.not(message_uid: nil).with_deleted.order(:created_at)

    unless start_date
      if (last_messsage = messages.last).present?
        start_date = last_messsage.created_at - 1.day
      end

      start_date ||= media_channel.updated_at
    end
    if media_channel.imap_settings.use_365_mailer
      query_date = start_date.strftime("%m/%d/%Y")
      ImapService.test({ "use_365_mailer" => "1", "media_channel_id" => media_channel.id })
      token = "Bearer #{ media_channel.imap_settings.microsoft_token}"
      headers = { 'Content-Type' => 'application/json', 'Authorization' => token }
      url = 'https://graph.microsoft.com/v1.0/me/mailFolders/inbox/messages?$search="received>='+query_date+'"'
      response = HTTParty.get(url, headers: headers)
      body = JSON.parse(response.body)
      body["value"].each do |email|
        puts '*****************************************'
        puts email
        id = email["internetMessageId"]
        body = email["bodyPreview"]
        yield(email, body, id)
      end
    else
      since_date  = Net::IMAP.format_date(start_date - 1.day)
      search_args = ['SINCE', since_date]
      @imap.examine('INBOX')
      p search_args
      @imap.search(search_args).each do |message_id|
        fetched_msg = @imap.fetch(message_id, '(UID RFC822)')[0]
        mail        = ::Mail.new(fetched_msg.attr['RFC822'])
        msg_uid     = fetched_msg.attr['UID']
        next if messages.where(message_uid: msg_uid).exists? # || all_messages.where(message_uid: msg_uid).count > 0

        email_text = ''
        charset    = 'UTF-8'
        html       = false
        if mail.multipart?
          if mail.text_part
            email_text = mail.text_part.body.decoded
            charset    = mail.text_part.charset
          elsif mail.html_part
            email_text = mail.html_part.body.decoded
            charset    = mail.html_part.charset
            html       = true
          end
        else
          email_text = mail.body.decoded
          charset    = mail.charset
          html       = !(/text\/html/.match(mail.content_type).nil?)
        end
        begin
          if Rails.env.production? || Rails.env.staging?
            # charlock_holmes magic.
            email_text = email_text.detect_encoding!
                                   .encode('UTF-8', {:invalid => :replace, :undef => :replace, :replace => '?'})
          end

          email_text = ::Helpers::HtmlToText.convert(email_text) if html
          # puts "EMAIL_TEXT : #{email_text}"
        rescue ::Encoding::CompatibilityError => e
          # puts "Subject: #{mail.subject}\n Body: #{email_text[0..1000]}"
          # puts "Error on parsing email with subject \"#{mail.subject}\": #{e.message}"
        end

        yield(mail, email_text, msg_uid)
      end
    end
  rescue => e
    # puts "Error fetching email (#{@settings.server_name}): #{e.message} #{e.backtrace.join("\n")}"
  ensure
    self.disconnect unless keepalive
  end

  # ImapService.fetch_emails(MediaChannel::Email.last)
  class << self
    def fetch_emails(media_channel, start_date = nil)
      new(media_channel.imap_settings).fetch_from_imap(media_channel, start_date) do |mail, email_text, msg_uid|
        media_channel.add_fetched_email_task(
          mail, email_text, msg_uid, need_push_to_browser: true, use_365_mailer: media_channel.imap_settings.use_365_mailer
        )
      end
    end

    def mark_as_read(media_channel, message_id)
      message = Message.find_by_id(message_id)
      if message.present? && message.marked_as_read == false
        new(media_channel.imap_settings).mark_email_as_read(message.message_uid) do
          message.update_attribute(:marked_as_read, true)
        end
      end
    end

    def test(settings)
      if settings["use_365_mailer"] == "1" || settings["use_365_mailer"] == true
        channel = MediaChannel.find(settings["media_channel_id"])
        imap_setting = channel.imap_settings
        refresh_token = imap_setting.ms_refresh_token
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
          imap_setting.update(
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
        imap    = Net::IMAP.new(settings[:server_name], settings[:port], use_ssl)
        imap.login(settings[:user_name], settings[:password])
        { success: true }
      end
    rescue => ex
      ::Rails.logger.info "Exception connecting to IMAP server: #{ex.message} #{ex.backtrace.join("\n")}"
      { success: false, message: ex.message }
    ensure
      imap.disconnect unless !imap || imap.disconnected?
    end

    # def mark_as_read(message_id)
    #   @imap    = Net::IMAP.new(settings[:server_name], settings[:port], settings[:use_ssl])
    #   @imap.login(settings[:user_name], settings[:password])
    #   inbox = @imap.select('INBOX')
    #   email_new = @imap.search('NEW')
    # end
  end
end

