require_relative "../config/environment.rb"
require 'active_support/inflector' #<<<<<<<The #pluralize method is provided to us by the active_support/inflector code library,
#  required at the top of lib/song.rb.>>>>>

# require 'pry'
class Song

  # Now that we understand what we need to do, let's write a method that returns the name of a table, given the name of a class:

    # The <<<<<#table_name Method>>>>>

  def self.table_name
    self.to_s.downcase.pluralize
  end

  # This method, which you'll see in the Song class in lib/song.rb, takes the name of the class, 
  # referenced by the self keyword, turns it into a string with #to_s, downcases (or "un-capitalizes") that string and then "pluralizes" it, 
  # or makes it plural.
  
  # ***************************************************
  # ***************************************************
  
  def self.column_names
    DB[:conn].results_as_hash = true

    sql = "pragma table_info('#{table_name}')" #<<<<<<This line of code that utilizes PRAGMA will return to us 
    # (thanks to our handy #results_as_hash method) an array of hashes describing the table itself. 
    # Each hash will contain information about one column. 

    table_info = DB[:conn].execute(sql)
    column_names = []
    table_info.each do |row|
      column_names << row["name"]
    end
    column_names.compact
  end


  # Here we write a SQL statement using the pragma keyword and the #table_name method (to access the name of the table we are querying). 
  # We iterate over the resulting array of hashes to collect just the name of each column. 
  # We call ~~#compact~~ on that just to be safe and get rid of any nil values that may end up in our collection.

  # The return value of calling Song.column_names will therefore be:

  # ["id", "name", "album"]

  # Now that we have a method that returns us an array of column names, 
  # we can use this collection to create the attr_accessors of our Song class.

# ***************************************************
# ***************************************************

#>>>>>>>>>> Metaprogramming our attr_accessors<<<<<<<<<<<<<<<

# We can tell our Song class that it should have an attr_accessor named after each column name with the following code:

  self.column_names.each do |col_name|
    attr_accessor col_name.to_sym
  end

  # Here, we iterate over the column names stored in the column_names class method and set an attr_accessor for each one, 
  # making sure to convert the column name string into a symbol with the #to_sym method, since attr_accessors must be named with symbols.

  # This is metaprogramming because we are writing code that writes code for us. 
  # By setting the attr_accessors in this way, a reader and writer method for each column name is dynamically created, 
  # without us ever having to explicitly name each of these methods.

  # ***************************************************
  # ***************************************************

# We want to be able to create a new song like this:

# song = Song.new(name: "Hello", album: "25")
# song.name
# # => "Hello"
# song.album
# # => "25"

# So, we need to define our #initialize method to take in a hash of named, or keyword, arguments. 
# However, we don't want to explicitly name those arguments. Here's how we can do it:

  def initialize(options={})
    options.each do |property, value|
      self.send("#{property}=", value)
    end
  end

#   ^^^^^Here, we define our method to take in an argument of options, which defaults to an empty hash. ^^^^^^
#   We expect #new to be called with a hash, so when we refer to options inside the #initialize method, 
#   we expect to be operating on a hash.

# We iterate over the options hash and use our fancy metaprogramming
#  #send method to interpolate the name of each hash key as a method that we set equal to that key's value.
#   As long as each property has a corresponding attr_accessor, this #initialize method will work.


# ***************************************************
# ***************************************************


  def save
    sql = "INSERT INTO #{table_name_for_insert} (#{col_names_for_insert}) VALUES (#{values_for_insert})"
    DB[:conn].execute(sql)
    @id = DB[:conn].execute("SELECT last_insert_rowid() FROM #{table_name_for_insert}")[0][0]
  end

  def table_name_for_insert
    self.class.table_name
  end

  def values_for_insert
    values = []
    self.class.column_names.each do |col_name|
      values << "'#{send(col_name)}'" unless send(col_name).nil?
    end
    values.join(", ")
  end

  def col_names_for_insert
    self.class.column_names.delete_if {|col| col == "id"}.join(", ")
  end

  def self.find_by_name(name)
    sql = "SELECT * FROM #{self.table_name} WHERE name = '#{name}'"
    DB[:conn].execute(sql)
    
  end

end



