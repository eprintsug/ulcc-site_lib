# Item types the UKRI OA policy applies to
$c->{ukri_oa}->{item_types} = ['article', 'conference_item'];

# Define additional fields for helping comply with UKRI policy
push @{ $c->{ukri_oa}->{profile} },
{
    name => "data_access_statement",
    type => "longtext",
    sql_index => 0,
},
{
    name => "ukri_date_sub",
    type => "date",
    sql_index => 0,
};

for( @{ $c->{ukri_oa}->{profile} } )
{
    $c->add_dataset_field( "eprint", $_ );
}

use Time::Piece;

# attempt to set ukri_date_sub from various sources
# this is used only to see if something is within scope, i.e. submitted after 1st April 2022
# therefore any date type will do, but submitted date is best
$c->add_dataset_trigger( 'eprint', EPrints::Const::EP_TRIGGER_BEFORE_COMMIT, sub
{
    my( %args ) = @_;
    my( $repo, $eprint, $changed ) = @args{qw( repository dataobj changed )};

    # trigger only applies to repos with ukri_oa plugin enabled
    return unless $eprint->dataset->has_field( 'ukri_date_sub' );

    my %priority = (
        published => 4,
        published_online => 3,
        accepted => 2,
        submitted => 1,
        default => 99,
    );

    # datesdatesdates
    if( $eprint->exists_and_set( 'dates' ) )
    {
        my @dates = sort {
            $priority{$a->{date_type} || "default"} <=> $priority{$b->{date_type} || "default"}
        } @{ $eprint->value( "dates" ) };

        my $date = scalar @dates ? $dates[0]->{date} : undef;
        my $date_type = scalar @dates ? $dates[0]->{date_type} : undef;

        if( defined $date_type && $date_type ne "default" ) # we have one of the acceptable date types
        {
            $eprint->set_value( 'ukri_date_sub', $date );
        }
    }
    elsif( $eprint->is_set( 'date' ) && $eprint->is_set( 'date_type' ) )
    {
        my $date_type = $eprint->value( 'date_type' );
        if( grep { $date_type eq $_ } keys %priority )
        {
            $eprint->set_value( 'ukri_date_sub', $eprint->value( 'date' ) );
        }
    }
}, priority => 100 );
