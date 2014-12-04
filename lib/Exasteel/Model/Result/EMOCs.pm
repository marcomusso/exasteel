package Exasteel::Model::Result::EMOCs;

use base qw/DBIx::Class::Core/;

 # Associated table in database
 __PACKAGE__->table('emocs');

 # Column definition
 __PACKAGE__->add_columns(

      id => {
          data_type => 'integer',
          is_auto_increment => 1,
      },

      name => {
          data_type => 'text',
      },

      description => {
          data_type => 'text',
      },

      endpoint => {
          data_type => 'text',
      },

      username => {
          data_type => 'text',
      },

      password => {
          data_type => 'text',
      }
  );

# Tell DBIC that 'id' is the primary key
__PACKAGE__->set_primary_key('id');

1;
