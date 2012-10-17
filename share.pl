use Mojolicious::Lite;
use lib 'share/lib';
use Share::Schema;

use Digest::MD5 qw/md5_hex/;
use Crypt::CBC;
use Data::Dumper;

app->config(hypnotoad => {pid_file=>'.share', listen=>['http://*:3006'], proxy=>1});
app->secret('My secret passphrase here');
helper db => sub { Share::Schema->connect({dsn=>'DBI:mysql:database=share;host=localhost',user=>'share',password=>'share'}) };

use constant PASSMSG => 'Optional Encryption Password';

# TO DO
#   Expire records on date or demand (optional)
#   Change or remove encryption
#   Link and Maps support
#   Attachment support

get '/share';
any '/:code' => sub { shift->redirect_to('codeview') };
get '/' => sub { shift->redirect_to('/'.substr(md5_hex(time), 0, 5).'/edit') }; # Make sure it doesn't already exist

get '/:code/raw' => sub {
	my $self = shift;

	my $code = $self->param('code');
	my $password = $self->session->{$code} = $self->param('password') || $self->session->{$code} || undef;
	my $cipher = $password ? new Crypt::CBC(-key=>$password, -cipher=>'Blowfish') : undef;

	my $code_rec;
	return $self->render_not_found unless $code_rec = $self->db->resultset("Share")->find({code=>$code});
	return $self->render_not_found if $code_rec->encrypted && not defined $cipher;
	my $share = defined $cipher ? $cipher->decrypt_hex($code_rec->share) : $code_rec->share;

	return $self->render(text => $share, format => 'txt');
};

any '/:code/view' => sub {
	my $self = shift;

	my $code = $self->param('code');
	my $password = $self->session->{$code} = $self->param('password') || $self->session->{$code} || undef;
	my $cipher = $password ? new Crypt::CBC(-key=>$password, -cipher=>'Blowfish') : undef;

	my $code_rec;
	return $self->render_not_found unless $code_rec = $self->db->resultset("Share")->find({code=>$code});
	my $share = $code_rec->encrypted ? defined $cipher ? $cipher->decrypt_hex($code_rec->share) : undef : $code_rec->share;

	my $data = {share => $share, code_rec => $code_rec};
	return $self->respond_to(
		json => {json => $data},
		html => {template => 'view', %{$data}},
	);
};

any '/:code/edit' => sub {
	my $self = shift;

	my $code = $self->param('code');
	my $password = $self->session->{$code} = $self->param('password') || $self->session->{$code} || undef;
	my $cipher = $password ? new Crypt::CBC(-key=>$password, -cipher=>'Blowfish') : undef;

	if ( $self->param('share') ) {
		my $share = defined $cipher ? $cipher->encrypt_hex($self->param('share')) : $self->param('share');
		$self->db->resultset("Share")->update_or_create({code=>$code, share=>$share, encrypted=>$cipher?1:0}, {key=>'code'});
	}

	my $code_rec = $self->db->resultset("Share")->find({code=>$code});
	my $share = defined $code_rec ? $code_rec->encrypted ? defined $cipher ? $cipher->decrypt_hex($code_rec->share) : undef : $code_rec->share : undef;

	my $data = {share => $share, code_rec => $code_rec};
	$self->stash(format => 'json') if $self->req->is_xhr;
	return $self->respond_to(
		json => {json => $data},
		html => {template => 'edit', %{$data}},
	);
};

any '/:code/:cmd' => {cmd => 'raw'} => sub {
	my $self = shift;
	return $self->render_not_found;

	my $cipher = $self->param('password') && $self->param('password') ne PASSMSG ? new Crypt::CBC(-key=>$self->param('password'), -cipher=>'Blowfish') : undef;
	my $code = $self->param('code');

	my $share;
	if ( $share = $self->param('share') ) {
		my %share = $cipher ? (share=>$cipher->encrypt_hex($self->param('share')), encrypted=>1) : (share=>$self->param('share'), encrypted=>0);
		$self->db->resultset("Share")->update_or_create({code=>$code, %share}, {key=>'code'});
	} else {
		if ( my $code_rec = $self->db->resultset("Share")->find({code=>$code}) ) {
			$share = $cipher ? $cipher->decrypt_hex($code_rec->share) : $code_rec->encrypted ? undef : $code_rec->share;
		}
	}

	my $data = {
		cmd => $self->param('cmd'),
		shareurl => "/$code",
		viewurl => "/$code/view",
		editurl => "/$code/edit",
		code => $code,
		share => $share||'',
	};

	#return $self->redirect_to($data->{editurl}) unless $share && $self->param('cmd') eq 'edit';
	return $self->respond_to(
		json => {json => $data},
		html => {
			$self->param('cmd') eq 'raw' ? (text => $share||'', format => 'txt') : (template => 'share', data => $data),
		},
	);
};

sub files {
	my $self = shift;

	local $/ = undef;
	open FILE, $ENV{DOCUMENT_ROOT}.'/'.$self->param('file') or return undef;
	my $file = <FILE>;
	close FILE;
	#$self->header_add(-type => $self->mime_type($ENV{DOCUMENT_ROOT}.'/'.$self->param('file')));
	return $file;
}

app->start;

__DATA__

@@ view.html.ep
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" lang="en-US" xml:lang="en-US">
<head>
<title>Text Share : View</title>
<link   href="http://ajax.googleapis.com/ajax/libs/jqueryui/1.8/themes/base/jquery-ui.css" type="text/css" rel="stylesheet" media="all" />
<script src="http://ajax.googleapis.com/ajax/libs/jquery/1.8/jquery.min.js" type="text/javascript"></script>
<script src="http://ajax.googleapis.com/ajax/libs/jqueryui/1.8/jquery-ui.min.js" type="text/javascript"></script>
<script src="/share.js?cmd=edit" type="text/javascript"></script>
<link   href="/share.css" type="text/css" rel="stylesheet" media="all" />
</head>
<body>
<div id="shareurl">Share: <%= link_to url_for('code', code=>$code_rec->code)->to_abs => begin %><%= url_for('code', code=>$code_rec->code)->to_abs %><% end %></div>
<div id="rawurl">Raw: <%= link_to url_for('coderaw', code=>$code_rec->code)->to_abs => begin %><%= url_for('coderaw', code=>$code_rec->code)->to_abs %><% end %></div>
<div id="editurl">Edit: <%= link_to url_for('codeedit', code=>$code_rec->code)->to_abs => begin %><%= url_for('codeedit', code=>$code_rec->code)->to_abs %><% end %></div>
<hr />
<span id="submit">Submit</span>
<input type="text" id="password" name="password" value="Optional Encryption Password" onfocus="if(this.value=='Optional Encryption Password'){this.value='';}" onblur="if(this.value==''){this.value='Optional Encryption Password';}" />
<hr />
<div id="view"><%= $share %></div>
<hr />
%# pre(&style).
%# pre(script($data)).
</body>
</html>

@@ edit.html.ep
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" lang="en-US" xml:lang="en-US">
<head>
<title>Text Share : Edit</title>
<link   href="http://ajax.googleapis.com/ajax/libs/jqueryui/1.8/themes/base/jquery-ui.css" type="text/css" rel="stylesheet" media="all" />
<script src="http://ajax.googleapis.com/ajax/libs/jquery/1.8/jquery.min.js" type="text/javascript"></script>
<script src="http://ajax.googleapis.com/ajax/libs/jqueryui/1.8/jquery-ui.min.js" type="text/javascript"></script>
<script src="/share.js?cmd=edit" type="text/javascript"></script>
<link   href="/share.css" type="text/css" rel="stylesheet" media="all" />
</head>
<body>
<div id="shareurl">Share: <%= link_to url_for('code', code=>$code_rec->code)->to_abs => begin %><%= url_for('code', code=>$code_rec->code)->to_abs %><% end %></div>
<div id="rawurl">Raw: <%= link_to url_for('coderaw', code=>$code_rec->code)->to_abs => begin %><%= url_for('coderaw', code=>$code_rec->code)->to_abs %><% end %></div>
<hr />
<span id="submit">Submit</span>
<input type="text" id="password" value="Optional Encryption Password" onfocus="if(this.value=='Optional Encryption Password'){this.value='';}" onblur="if(this.value==''){this.value='Optional Encryption Password';}" class="ui-widget-content" />
<br />
<textarea id="edit"><%= $share %></textarea>
<hr />
%# pre(&style).
%# pre(script($data)).
</body>
</html>

@@ share.js.ep
$(document).ready(function(){
	<%= $self->param('cmd') ? '' : '$("#viewurl").hide();' %>
	$('#submit').addClass('ready');
	$('#password').addClass('ready');
	$('#edit').addClass('ready');
	$('#edit').resizable();
	if ( $('#edit').val() != "" ) {
		$('#viewurl').hide();
	}
	$('#submit').hover(function(){
		$(this).addClass('cursor_default');
	}, function(){
		$(this).removeClass('cursor_default');
	});
	$('#edit').keypress(function(event){
		//alert(event.keyCode);
		$('#submit').addClass('changed');
		$('#submit').removeClass('ready');
		$('#password').addClass('changed');
		$('#password').removeClass('ready');
		$('#edit').addClass('changed');
		$('#edit').removeClass('ready');
	});
	$('#submit').click(function(){
		$.ajax({
			type: 'POST',
			url: '<%= $self->param('cmd') %>',
			cache: false,
			data: {
				password: $('#password').val() == "Optional Encryption Password" ? "" : $('#password').val(),
				share: $('#edit').val()
			},
			dataType: 'json',
			success: function(data) {
				$('#submit').addClass('ready');
				$('#submit').removeClass('changed');
				$('#password').addClass('ready');
				$('#password').removeClass('changed');
				$('#edit').addClass('ready');
				$('#edit').removeClass('changed');
				$('#view').html('<pre>' + data.share + '</pre>');
				$('#viewurl').show();
			}
		});
	});
});

@@ share.css.ep
span#submit { border: none; padding: 4px; }
input#password { }
textarea#edit { width: 800px; height: 600px; padding: 6px; font-family: Tahoma, sans-serif; }
span.ready { background: green; }
span.changed { background: red; }
span.cursor_default { cursor: default; }
input.ready { border: 3px solid green; }
input.changed { border: 3px solid red; }
textarea.ready { border: 3px solid green; }
textarea.changed { border: 3px solid red; }
