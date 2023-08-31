class MediaChannelService
  def initialize(media_channel)
    @media_channel = ::MediaChannel.find(media_channel)
  end

  def check_active_state
    smtp_setting = @media_channel.smtp_settings.attributes.merge("media_channel_id" => @media_channel.id)
    imap_setting = @media_channel.imap_settings.attributes.merge("media_channel_id" => @media_channel.id)
    if smtp_setting["use_365_mailer"] || imap_setting["use_365_mailer"]
      res = ::SmtpService.test(smtp_setting)[:success] && ::ImapService.test(imap_setting)[:success]
    else
      res = ::ImapService.test(@media_channel.imap_settings)[:success] && ::SmtpService.test(@media_channel.smtp_settings)[:success]
    end
    if res
      @media_channel.update_columns(active: res, broken: !res)
    else
      @media_channel.update_columns(active: res, broken: !res)
    end
  end
end

