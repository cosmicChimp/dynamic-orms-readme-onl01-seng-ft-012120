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
  
  <def self.column_names
    DB[:conn].results_as_hash = true>

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

  <self.column_names.each do |col_name|
    attr_accessor col_name.to_sym
  end>

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

  <def initialize(options={})
    options.each do |property, value|
      self.send("#{property}=", value)
    end
  end>

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

********************************************************************************
********************************************************************************
|                            ENVIRONMENT                                        |

# >>>>>Step 1: Setting Up the Database<<<<<

# For this exercise, we'll be working with a Song class. To create a dynamic ORM, we start by creating our database and songs table. 
# In config/environment.rb you'll find the following code:

require 'sqlite3'


DB = {:conn => SQLite3::Database.new("db/songs.db")}
DB[:conn].execute("DROP TABLE IF EXISTS songs")

"sql = <<-SQL
  CREATE TABLE IF NOT EXISTS songs (
  id INTEGER PRIMARY KEY,
  name TEXT,
  album TEXT
  )
SQL    "                                    

DB[:conn].execute(sql)
DB[:conn].results_as_hash = true



# Here we are doing a couple of things:

--# Creating the database.
--# Drop songs to avoid an error.
--# Creating the songs table.

# Lastly, we use the "***#results_as_hash method****", available to use from the SQLite3-Ruby gem. 

# This method says: when a SELECT statement is executed, don't return a database row as an array, 
# return it as a hash with the column names as keys.

# So, instead of DB[:conn].execute("SELECT * FROM songs LIMIT 1") returning something that looks like this:

# [[1, "Hello", "25"]]
# It will return something that looks like this:

# {"id"=>1, "name"=>"Hello", "album"=>"25", 0 => 1, 1 => "Hello", 2 => "25"}

# This will be helpful to us as we use information requested from our database table to build attributes and methods on our Song class, 
# but more on that later.


********************************************************************************
********************************************************************************



***SAVING RECORDS IN A DYNAMIC MANNER***
Let's take a look at the basic SQL statement required to save a given song record:

INSERT INTO songs (name, album)
VALUES 'Hello', '25';

In order to write a method that can INSERT any record to any table, we need to be able to craft the above SQL statement
without explicitly referencing the songs table or column names and without explicitly referencing the values of a given Song instance.

---Abstracting the Table Name---

Luckily for us, we already have a method to give us the table name associated to any given class: <class name>.table_name.
 <!-- <REFERENCE Song.rb .table_name> -->

Recall, however, that the conventional <<<<#save>>>> is an instance method. So, inside a <<<<#save method>>>>, self will refer to the instance of the class, not the class itself. In order to use a class method inside an instance method, we need to do the following:

(def some_instance_method
  self.class.some_class_method
end)

    -So, to access the table name we want to INSERT into from inside our #save method, we will use the following:

    -(self.class.table_name)

        --We can wrap up this code in a handy method, #table_name_for_insert:

        --(def table_name_for_insert
            <<<self.class.table_name>>>
        end)

---------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------------

---Abstracting the Column Names---

We already have a handy method for grabbing the column names of the table associated with a given class:
<<<self.class.column_names>>>  <!-- <REFERENCE Song.rb .column_names> -->

In the case of our Song class, this will return:
["id", "name", "album"]

There's one problem though. When we INSERT a row into a database table for the first time, we don't INSERT the id attribute. In fact, our Ruby object has an id of nil before it is inserted into the table. The magic of our SQL database handles the creation of an ID for a given table row and then we will use that ID to assign a value to the original object's id attribute.

So, when we save our Ruby object, we should not include the id column name or insert a value for the id column. Therefore, we need to remove "id" from the array of column names returned from the method call above:
<<<self.class.column_names.delete_if {|col| col == "id"}>>>
This will return:

["name", "album"]

Notice that the column names in the statement are comma separated. Our column names returned by the code above are in an array. Let's turn them into a comma separated list, contained in a string:

<<<self.class.column_names.delete_if {|col| col == "id"}.join(", ")>>>
This will return:                                        ^^^^^^^^^^

"name, album"

We can wrap up this code in a handy method, #col_names_for_insert:

(def col_names_for_insert   <!-- <REFERENCE Song.rb == col_names_for_insert> -->
  <<<self.class.column_names.delete_if {|col| col == "id"}.join(", ")>>>
end)

Lastly, we need an abstract way to grab the values we want to insert.

---------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------------

---Abstracting the Values to Insert---

When inserting a row into our table, we grab the values to insert by grabbing the values of that instance's attr_readers. How can we grab these values without calling the reader methods by name?

We already know that the names of that attr_accessor methods were derived from the column names of the table associated to our class. Those column names are stored in the #column_names class method.

In fact, we already know how to programmatically invoke a method, without knowing the exact name of the method, using the #send method.

Let's iterate over the column names stored in #column_names and use the #send method with each individual column name to invoke the method by that same name and capture the return value:

<values = []
 
<self.class.column_names.each do |col_name|
  values << "'#{send(col_name)}'" unless send(col_name).nil?
end>

Here, we push the return value of invoking a method via the #send method, unless that value is nil (as it would be for the id method before a record is saved, for instance).

Notice that we are wrapping the return value in a string. That is because we are trying to craft a string of SQL. Also notice that each individual value will be enclosed in single quotes, ' ', inside that string. That is because the final SQL string will need to look like this:

<INSERT INTO songs (name, album)
VALUES 'Hello', '25';>

SQL expects us to pass in each column value in single quotes.
The above code, however, will result in a values array

["'the name of the song'", "'the album of the song'"]
We need comma separated values for our SQL statement. Let's join this array into a string:

<values.join(", ")>

Let's wrap up this code in a handy method, #values_for_insert:

<def values_for_insert   
  values = []
  self.class.column_names.each do |col_name|
    values << "'#{send(col_name)}'" unless send(col_name).nil?
  end
  values.join(", ")
end> <!--REFERENCE Song.rb == values_for_insert-->

Now that we have abstract, flexible ways to grab each of the constituent parts of the SQL statement to save a record, let's put them all together into the #save method:

**The #save Method:**

<def save
  DB[:conn].execute("INSERT INTO #{table_name_for_insert} (#{col_names_for_insert}) VALUES (?)", [values_for_insert])
  @id = DB[:conn].execute("SELECT last_insert_rowid() FROM #{table_name_for_insert}")[0][0]
end>

>>>>Note: Using String interpolation for a SQL query creates a SQL injection vulnerability, which we've previously stated is a bad idea as it creates a security issue, however, we're using these examples to illustrate how dynamic ORMs work.<<<<

---Selecting Records in a Dynamic Manner---


Now that we have a better understanding of how our dynamic, abstract, ORM works, let's build the #find_by_name method.

<def self.find_by_name(name)
  DB[:conn].execute("SELECT * FROM #{self.table_name} WHERE name = ?", [name])
end>

>>>>Note: Using String interpolation for a SQL query creates a SQL injection vulnerability, which we've previously stated is a bad idea as it creates a security issue, however, we're using these examples to illustrate how dynamic ORMs work.<<<<

This method is dynamic and abstract because it does not reference the table name explicitly. Instead it uses the #table_name class method we built that will return the table name associated with any given class.