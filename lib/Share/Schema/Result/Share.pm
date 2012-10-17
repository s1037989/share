package Share::Schema::Result::Share;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components("InflateColumn::DateTime");

=head1 NAME

Share::Schema::Result::Share

=cut

__PACKAGE__->table("share");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 code

  data_type: 'varchar'
  is_nullable: 1
  size: 5

=head2 share

  data_type: 'text'
  is_nullable: 1

=head2 encrypted

  data_type: 'tinyint'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "code",
  { data_type => "varchar", is_nullable => 1, size => 5 },
  "share",
  { data_type => "text", is_nullable => 1 },
  "encrypted",
  { data_type => "tinyint", is_nullable => 1 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("code", ["code"]);


# Created by DBIx::Class::Schema::Loader v0.07010 @ 2012-10-16 17:05:21
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:of6XR8e0TNbYdGHHRhk8Yg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
