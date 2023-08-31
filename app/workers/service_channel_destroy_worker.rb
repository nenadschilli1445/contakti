class ServiceChannelDestroyWorker
  include ::Sidekiq::Worker
  def perform(id)
    begin
      ::ServiceChannel.find(id).really_destroy!
    rescue
    end
  end
end
