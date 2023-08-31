class MessageSerializer < ActiveModel::Serializer
  attributes :id,
             :channel_type,
             :created_at,
             :is_internal,
             :number,
             :sms,
             :in_reply_to_id,
             :task_id,
             :title,
             :to,
             :from_email,
             :user_id,
             :from,
             :inbound,
             :cc,
             :bcc,
             :call_transcript,
             :marked_as_read,
             :is_call_recording

  def in_reply_to_id
    object[:in_reply_to_id]
  end

  def attachments
    object.attachments.map do |attachment|
      Message::AttachmentSerializer.new(attachment, root: false)
    end
  end

  def is_call_recording
    call_recording = false
    object.attachments.map do |attachment|
      if attachment.is_call_recording
        call_recording = true
        break
      end
    end
    call_recording
  end
end
