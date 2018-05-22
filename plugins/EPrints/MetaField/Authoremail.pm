######################################################################
#
# EPrints::MetaField::Authoremail;
#
######################################################################

package EPrints::MetaField::Authoremail;

use strict;
use warnings;

use EPrints::MetaField::Text;

BEGIN {
    our (@ISA);
    @ISA = qw( EPrints::MetaField::Text );
}

sub _get_name {
    my ( $self, $session, $value ) = @_;

    return "" unless ( EPrints::Utils::is_set($value) );

    my $name = $value;

    my $ds = $session->dataset("eprint");
    my $searchexp = $ds->prepare_search();
    $searchexp->add_field(
        fields => [ $ds->field('creators_id') ],
        value  => $value,
        match  => "EQ",
    );

    my $eprint = $searchexp->perform_search->item(0);

    if ( defined $eprint ) {
        for my $creator ( @{ $eprint->get_value("creators") } ) {
            if ( defined $creator->{id} ) {
                if ( $creator->{id} eq $value ) {
                    $name =
                      EPrints::Utils::make_name_string( $creator->{name} );
                }
            }
        }
    }
    return $name;
}

sub get_value_label {
    my ( $self, $session, $value ) = @_;
    my $name = $self->_get_name( $session, $value );
    return $session->make_text($name);
}

sub ordervalue_basic {
    my ( $self, $value, $session, $langid ) = @_;
    my @name = $self->_get_name( $session, $value );
    return $session->make_text($name);
}

sub render_single_value {
    my ( $self, $session, $value ) = @_;
    return $self->get_value_label( $session, $value );
}

1;
