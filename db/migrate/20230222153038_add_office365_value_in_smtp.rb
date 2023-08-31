class AddOffice365ValueInSmtp < ActiveRecord::Migration
  def change
    add_column :smtp_settings, :use_365_mailer, :boolean, default: false
    add_column :imap_settings, :use_365_mailer, :boolean, default: false

  end
end
