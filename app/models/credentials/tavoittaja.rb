class Credentials::Tavoittaja < ActiveRecord::Base
  validates_presence_of :username, :password
end
