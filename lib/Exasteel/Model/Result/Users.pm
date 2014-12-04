package Exasteel::Model::Result::Users;

use base qw/DBIx::Class::Core/;

 # Associated table in database
 __PACKAGE__->table('users');

 # Column definition
 __PACKAGE__->add_columns(

      id => {
          data_type => 'integer',
          is_auto_increment => 1,
      },

      username => {
          data_type => 'text',
      },

      email => {
          data_type => 'text',
      },

      role => {
          data_type => 'text',
      },

      lastlogin => {
          data_type => 'datetime',
      },

  );

# Tell DBIC that 'id' is the primary key
__PACKAGE__->set_primary_key('id');

"We came, we saw, we kicked its ass! (Ghostbusters, 1984)";
