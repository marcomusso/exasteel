package Exasteel::Controller::Auth;

use base 'Mojolicious::Controller';
use Mojo::Log;
use Data::Dumper;

sub create {
  my $self=shift;
  my $log=$self->main_log;
  my $log_level=$self->log_level;

  my $username = $self->param('username');
  my $password = $self->param('password');

  if ($log_level>0) { $log->debug("Exasteel::Controller::Auth::create"); }

  if ($username eq "admin" && $password eq "admin") {
    $self->session(
      username => $username,
      email    => ''
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

  $self->session( username => '' )->redirect_to('auth_login');
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
