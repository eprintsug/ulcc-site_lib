# Item types the UKRI OA policy applies to
$c->{plan_s}->{item_types} = ['article', 'conference_item'];

$c->{plan_s_set_document_defaults} = $c->{set_document_defaults};
$c->{set_document_defaults} = sub
{
    my( $data, $repository, $eprint ) = @_;

    $repository->call( "plan_s_set_document_defaults", $data, $repository, $eprint );
 
    if( defined $eprint && grep { $eprint->value( "type" ) eq $_ } @{$repository->config( "plan_s", "item_types" )} )
    {
        $data->{license} = "cc_by_4" if !defined $data->{license};
    }
};
