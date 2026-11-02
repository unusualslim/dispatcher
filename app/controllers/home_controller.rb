# GET / for signed-in users: their chosen home page, else their role's default.
class HomeController < ApplicationController
  def show
    redirect_to home_path
  end
end
