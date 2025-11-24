
###############################################
# render_compound_respect_export_as_xml       #
#                                             #
# Render compound fields such that sub-fields #
# with export_as_xml set to 0 will not appear #
# in the little table                         #
# #############################################

$c->{render_compound_respect_export_as_xml} = sub {
        my( $repo, $field, $value, $alllangs, $nolink, $object ) = @_;

        my $table = $repo->make_element( "table", border=>1, cellspacing=>0, cellpadding=>2 );
        my $tr = $repo->make_element( "tr" );
        $table->appendChild( $tr );
        my $f = $field->get_property( "fields_cache" );
        foreach my $field_conf ( @{$f} )
        {
            my $fieldname = $field_conf->{name};
            my $field = $field->{dataset}->get_field( $fieldname );
            ######## IF WE DON@T export_as_xml WE DON'T show in html ########
            next if(!$field->get_property( "export_as_xml" ));
            #################################################################
            my $th = $repo->make_element( "th" );
            $tr->appendChild( $th );
            $th->appendChild( $field->render_name( $repo ) );
        }

        if( $field->get_property( "multiple" ) )
        {
            foreach my $row ( @{$value} )
            {
                #my( $self, $session, $value, $alllangs, $nolink, $object ) = @_;

                $table->appendChild( render_single_value_row( $repo, $field, $row, $alllangs, $nolink, $object ) );
            }
        }
        else
        {
            $table->appendChild( render_single_value_row( $repo, $field, $value, $alllangs, $nolink, $object ) );
        }
        return $table;
    };

{

no warnings 'redefine';

# Version of row render (for use with above only)
sub render_single_value_row {

    my ($repo, $field, $value, $alllangs, $nolink, $object) = @_;
    my $tr = $repo->make_element( "tr" );

    foreach my $f (@{$field->{fields_cache}})
    {
        ######## IF WE DON'T export_as_xml WE DON'T show in html ########
        next if(!$f->get_property( "export_as_xml" ));
        #################################################################
        my $alias = $f->property( "sub_name" );
        my $td = $repo->make_element( "td" );
        $tr->appendChild( $td );
        $td->appendChild( 
            $f->render_value_no_multiple( 
                $repo, 
                $value->{$alias}, 
                $alllangs,
                $nolink,
                $object ) );
    }

    return $tr;
 
}

}
