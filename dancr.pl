#!/usr/bin/perl

use Dancer;
use DBI;
use File::Spec;
use File::Slurp;
use Template;
 
set 'database'     => 'database';
set 'session'      => 'Simple';
set 'template'     => 'template_toolkit';
set 'logger'       => 'console';
set 'log'          => 'debug';
set 'show_errors'  => 1;
set 'startup_info' => 1;
set 'warnings'     => 1;
set 'username'     => 'admin';
set 'password'     => 'password';
set 'layout'       => 'main';

my $flash;
 
sub set_flash {
       my $message = shift;
 
       $flash = $message;
}
 
sub get_flash {
 
       my $msg = $flash;
       $flash = "";
 
       return $msg;
}
 
sub connect_db {
       my $dbh = DBI->connect("dbi:SQLite:dbname=".setting('database')) or
               die $DBI::errstr;
 
       return $dbh;
}
 
sub init_db {
       my $db = connect_db();
       my $schema = read_file('./schema.sql');
       $db->do($schema) or die $db->errstr;
}
 
hook before_template => sub {
       my $tokens = shift;
        
       $tokens->{'css_url'} = request->base . 'css/style.css';
       $tokens->{'login_url'} = uri_for('/login');
       $tokens->{'logout_url'} = uri_for('/logout');
};
 
get '/' => sub {
	my $db = connect_db(); # returns db file handle
	my $sql = 'select id, title, text from entries order by id desc'; # SQL code to obtain blog posts
	my $sth = $db->prepare($sql) or die $db->errstr;
	$sth->execute or die $sth->errstr;
	#send_file 'index.html';
	template 'show_entries.tt', {
		'msg' => get_flash(),
		'add_entry_url' => uri_for('/add'),
		'entries' => $sth->fetchall_hashref('id'),
	};
};

 
post '/add' => sub {
       if ( not session('logged_in') ) {
               send_error("Not logged in", 401);
       }
 
       my $db = connect_db();
       my $sql = 'insert into entries (title, text) values (?, ?)';
       my $sth = $db->prepare($sql) or die $db->errstr;
       $sth->execute(params->{'title'}, params->{'text'}) or die $sth->errstr;
 
       set_flash('New entry posted!');
       redirect '/';

};

post '/edit' => sub {
	if ( not session('logged_in') ) {
		send_error("Not logged in", 401);
	}
	
	my $db = connect_db();
	my $sql = 'update entries set text = ? where title = ?';
	my $sth = $db->prepare($sql) or die $db->errstr;
	$sth->execute(params->{'text'}, params-> {'title'}) or die $sth->errstr;

	set_flash('Entry modified!');
	redirect '/';


};

post '/remove' => sub {
	if (not session('logged_in') ) {
			send_error("Not logged in", 401);
	}
	
	my $db = connect_db();
	my $sql = 'delete from entries WHERE title=(?)';
	my $sth = $db->prepare($sql) or die $db->errstr;
	$sth->execute(params->{'title'}) or die $sth->errstr;

	set_flash('Entry deleted!');
	redirect '/';

};
 
any ['get', 'post'] => '/login' => sub {
	my $err;

	if (request->method() eq "POST"){
		if ( params->{'username'} ne setting('username') ) {
			$err = "Invalid username";
			send_error($err, 403);
		}	
		elsif ( params->{'password'} ne setting('password') ) {
			$err = "Invalid password";
			send_error($err, 403);
		}
		else {
			session 'logged_in' => true;
			set_flash('You are logged in.');
			return redirect '/';
		}
	}
 
    # display login form
	template 'login.tt', {
	      'err' => $err,
	};
 
};
 
get '/logout' => sub {
       session->destroy;
       set_flash('You are logged out.');
       redirect '/logout_page';
};

get '/logout_page' => sub {
	send_file 'logout.html';
};
 
init_db();
start;

