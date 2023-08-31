class AddMicrosoftTokenToUsers < ActiveRecord::Migration
  def change
      add_column :users, :microsoft_token, :text
      add_column :users, :ms_refresh_token, :text

  end
end
