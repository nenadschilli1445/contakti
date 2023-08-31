class AddTokenInSmtp < ActiveRecord::Migration
  def change
    add_column :smtp_settings, :microsoft_token, :text
    add_column :smtp_settings, :ms_refresh_token, :text
    add_column :smtp_settings, :expire_in, :string
    add_column :smtp_settings, :token_updated_at, :string


  end
end
