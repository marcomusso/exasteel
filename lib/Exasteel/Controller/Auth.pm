package Exasteel::Controller::Auth;

use base 'Mojolicious::Controller';
use Mojo::Log;
use Data::Dumper;
use DateTime;

sub create {
  my $self=shift;
  my $db=$self->db;
  my $log=$self->main_log;
  my $log_level=$self->log_level;

  my $username = $self->param('username');
  my $password = $self->param('password');

  if ($log_level>0) { $log->debug("Exasteel::Controller::Auth::create"); }

  my $users=$db->get_collection('users');  
  my $user=$users->find({"username" => "$username", "password" => crypt($password,$password)});  
  # let's retrieve all users that match the previous find (should be one of course)
  my @logged_user=$user->all;

  if ( @logged_user and (0+@logged_user)==1) {
    if ($log_level>0) { $log->debug("Exasteel::Controller::Auth::create Auth ok for $username"); }
    # set last login time
    $users->update({"_id" => $logged_user[0]->{'_id'}}, {'$set' => {'last_login' => DateTime->now}});
    $self->session(
      username => $username,
      email    => '',
      role     => $logged_user[0]->{'role'},
      expiration => time + 60*60*24*7
      )->redirect_to('/');
  } else {
    if ($log_level>0) { $log->debug("Exasteel::Controller::Auth::create login failed for $username"); }
    $self->flash( error => 'Unknown username or wrong password' )->redirect_to('auth_login');
  }
}

sub logout {
  my $self=shift;
  my $log=$self->main_log;
  my $log_level=$self->log_level;

  if ($log_level>0) { $log->debug("Exasteel::Controller::Auth::logout logout for ".$self->session('username')); }

  $self->session( username => '', expires => 1 )->redirect_to('auth_login');
}

sub check {
  my $self=shift;

  if ($self->session('username')) {
    return 1;
  } else {
    $self->render(template => 'auth/denied');
    return 0;
  }
}

"The gate will open if...";
