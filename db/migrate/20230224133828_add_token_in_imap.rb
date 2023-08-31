class AddTokenInImap < ActiveRecord::Migration
  def change
    add_column :imap_settings, :microsoft_token, :text
    add_column :imap_settings, :ms_refresh_token, :text
    add_column :imap_settings, :expire_in, :string
    add_column :imap_settings, :token_updated_at, :string
  end
end
