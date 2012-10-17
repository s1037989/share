package Cogent::Share;
use base 'Cogent::Share::Base';

use Digest::MD5 qw/md5_hex/;
use Crypt::CBC;

sub html : StartRunmode {
	my $self = shift;
	my $q = $self->query;

	my $passmsg = 'Optional Encryption Password';

	my $code = '';
	my $share = '';
	my $encrypted = 0;
	my $cipher = $self->query->param('password') && $self->query->param('password') ne $passmsg ? new Crypt::CBC(-key=>$self->query->param('password'), -cipher=>'Blowfish') : undef;

	if ( $code = $self->param('code') ) {
		if ( $share = $self->query->param('share') ) {
			if ( $self->dbh->selectrow_array('SELECT id FROM share WHERE code=? LIMIT 1', {}, $code) ) {
				$self->dbh->do('UPDATE share SET share=?,encrypted=? WHERE code=?', {}, ($cipher ? ($cipher->encrypt_hex($share), 1) : ($share, 0)), $code);
			} else {
				$self->dbh->do('INSERT INTO share VALUES (null, ?, ?, ?)', {}, $code, $cipher ? ($cipher->encrypt_hex($share), 1) : ($share, 0));
			}
		} else {
			($share, $encrypted) = $self->dbh->selectrow_array('SELECT share,encrypted FROM share WHERE code=? LIMIT 1', {}, $code);
			if ( $cipher ) {
				$share = $cipher->decrypt_hex($share);
			} else {
				$share = undef if $encrypted;
			}
		}
	} else {
		$code = substr(md5_hex(time), 0, 5);
	}

	if ( $share && !$self->param('cmd') ) {
		$self->header_add(-type => 'text/plain');
		return $share;
	} else {
		my $url = $self->query->url;
		$url =~ s!/$!!;
		my $data = {
			shareurl => $url."/$code",
			viewurl => $url."/$code/view",
			editurl => $url."/$code/edit",
			code => $code,
			share => $share||'',
		};
		return $self->to_json($data) if $self->is_ajax;
		if ( (not defined $share) || $self->param('cmd') eq 'view' ) {
			my @h = $self->query->Link({-rel=>'stylesheet',-type=>'text/css',-src=>'http://ajax.googleapis.com/ajax/libs/jqueryui/1.8/themes/base/jquery-ui.css',-media=>'all'});
			return
				$self->query->start_html(
					-title=>'Text Share',
					-head=>\@h,
					-script=>[
						{-type=>"text/javascript", -src=>"https://ajax.googleapis.com/ajax/libs/jquery/1.7/jquery.min.js"},
						{-type=>"text/javascript", -src=>"https://ajax.googleapis.com/ajax/libs/jquery/1.8.16/jquery-ui.min.js"},
						{-type=>"text/javascript", -code=>script($data, 'view')},
					],
					-style=>[
						{-code=>&style},
					],
				).
				$self->query->div({id=>'shareurl'}, "Share: ".$self->query->a({-href=>$data->{shareurl}}, $data->{shareurl})).
				#$self->query->div({id=>'editurl'}, "Edit: ".$self->query->a({-href=>$data->{editurl}}, $data->{editurl})).
				$self->query->hr."\n".
				($encrypted ? $self->query->span({id=>'submit'}, "Submit") : '').
				($encrypted ? $self->query->textfield(-id=>'password', -name=>'password', -default=>$passmsg, -onfocus=>"if(this.value==\'$passmsg\'){this.value=\'\';}", -onblur=>"if(this.value==\'\'){this.value=\'$passmsg\';}") : '').
				($encrypted ? $self->query->hr."\n" : '').
				$self->query->div({-id=>'view'}, $share||'').
				#$self->query->hr.
				#$self->query->pre(&style).
				#$self->query->pre(script($data)).
				$self->query->end_html."\n";
		} else {
			my @h = (
				$self->query->Link({-rel=>'stylesheet',-type=>'text/css',-src=>'http://ajax.googleapis.com/ajax/libs/jqueryui/1.8/themes/base/jquery-ui.css',-media=>'all'}),
				$self->query->Link({-rel=>'stylesheet',-type=>'text/css',-src=>'/css/ui-lightness/jquery-ui-1.8.16.custom.css',-media=>'all'}),
			);
			return
				$self->query->start_html(
					-title=>'Text Share',
					-head=>\@h,
					-script=>[
						{-type=>"text/javascript", -src=>"https://ajax.googleapis.com/ajax/libs/jquery/1.7/jquery.min.js"},
						{-type=>"text/javascript", -src=>"http://ajax.googleapis.com/ajax/libs/jqueryui/1.8.16/themes/base/jquery-ui.css"},
						{-type=>"text/javascript", -code=>script($data, 'edit')},
					],
					-style=>[
						{-code=>&style},
					],
				).
				$self->query->div({id=>'shareurl'}, "Share: ".$self->query->a({-href=>$data->{shareurl}}, $data->{shareurl})).
				$self->query->div({id=>'viewurl'}, "View: ".$self->query->a({-href=>$data->{viewurl}}, $data->{viewurl})).
				$self->query->hr."\n".
				$self->query->span({id=>'submit'}, "Submit").
				$self->query->textfield(-id=>'password', -default=>$passmsg, -onfocus=>"if(this.value==\'$passmsg\'){this.value=\'\';}", -onblur=>"if(this.value==\'\'){this.value=\'$passmsg\';}", -class=>'ui-widget-content').
				$self->query->br.
				$self->query->textarea(-id=>'edit', -default=>$share||'').
				#$self->query->hr.
				#$self->query->pre(&style).
				#$self->query->pre(script($data)).
				$self->query->end_html."\n";
		}
	}
}

# Make this a plugin?
sub files : Runmode {
	my $self = shift;

	local $/ = undef;
	open FILE, $ENV{DOCUMENT_ROOT}.'/'.$self->param('file') or return undef;
	my $file = <FILE>;
	close FILE;
	$self->header_add(-type => $self->mime_type($ENV{DOCUMENT_ROOT}.'/'.$self->param('file')));
	return $file;
}

# Move this into a file
sub style {
	return <<STYLE;
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
STYLE
}

# Move this into a template
sub script {
	my $data = shift;
	return <<SCRIPT;
	\$(function(){
		${\($data->{share} ? '' : "\$('#viewurl').hide();")}
		\$('#submit').addClass('ready');
		\$('#password').addClass('ready');
		\$('#edit').addClass('ready');
		\$('#edit').resizable();
		if ( \$('#edit').val() != "" ) {
			\$('#viewurl').hide();
		}
		\$('#submit').hover(function(){
			\$(this).addClass('cursor_default');
		}, function(){
			\$(this).removeClass('cursor_default');
		});
		\$('#edit').keypress(function(event){
			//alert(event.keyCode);
			\$('#submit').addClass('changed');
			\$('#submit').removeClass('ready');
			\$('#password').addClass('changed');
			\$('#password').removeClass('ready');
			\$('#edit').addClass('changed');
			\$('#edit').removeClass('ready');
		});
		\$('#submit').click(function(){
			\$.ajax({
				type:		'POST',
				url:		'$data->{"$_[0]url"}',
				cache:		false,
				data:		{password: \$('#password').val(), share: \$('#edit').val()},
				dataType:	'json',
				success:	function(data) {
							\$('#submit').addClass('ready');
							\$('#submit').removeClass('changed');
							\$('#password').addClass('ready');
							\$('#password').removeClass('changed');
							\$('#edit').addClass('ready');
							\$('#edit').removeClass('changed');
							\$('#view').html('<pre>' + data.share + '</pre>');
							\$('#viewurl').show();
						}
			});
		});
	});
SCRIPT
}

1;
