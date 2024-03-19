# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: "Star Wars" }, { name: "Lord of the Rings" }])
#   Character.create(name: "Luke", movie: movies.first)
# admin_emails = ['arthur@redkrypton.com', 'andy@redkrypton.com'].freeze
#
# admin_emails.each do |email|
#   admin = User.new
#   admin.email = email
#   admin.password = '#$taawktljasktlw4aaglj'
#   admin.save!
#   puts "#{email} has been created!"
# end

admin_new_emails = ['david@redkrypton.com', 'andylee.dreamsoft@gmail.com', 'andy@redkrypton.com', 'arthur@redkrypton.com', 'Jenn@eatcleanbro.com', 'stephen@eatcleanbro.com', 'matt.smoyak@eatcleanbro.com', 'johnny@getcuttingedge.com'].freeze

admin_new_emails.each do |email|
  admin = User.new
  admin.email = email
  admin.password = '#$taawktljasktlw4aaglj'
  admin.save!
  puts "#{email} has been created!"
end
