# Update the creators browse view to use ID browse 
# We need:
# 1) A browse view to update
# 2) A combination of fields, sub fields and a regex to apply it to OR
# 3) A function to apply
if( defined $c->{institution_browse_view} )
{
    # Set up the browse view
    my $institution_browse_view = $c->{institution_browse_view};
    for my $view ( @{ $c->{browse_views} } )
    {
        if( $view->{id} eq $institution_browse_view )
        {
            $view->{menus} = [
                {
                    fields => [ "users_id" ],
                    new_column_at => [1, 1],
                    mode => "sections",
                    open_first_section => 1,
                    group_range_function => "EPrints::Update::Views::cluster_ranges_30",
                    grouping_function => "EPrints::Update::Views::group_by_a_to_z",
              },
            ],
        }
    }

    # and ensure we have a users field
    push @{ $c->{fields}->{eprint} },
    {
        name => 'users',
        type => 'compound',
        sql_index => 0,
        multiple => 1,
        fields => [
            {
                sub_name => 'name',
                type => 'name',
                family_first => 1,
            },
            {
                sub_name => 'id',
                type => 'MD5',
                browse_link => $institution_browse_view,
                input_cols => 35,
            },
        ],
    };

	# apply the automatic fields
	if( defined $c->{institution_browse_view_filter} )
	{
		$c->add_dataset_trigger( 'eprint', EPrints::Const::EP_TRIGGER_BEFORE_COMMIT, sub
		{
    		my( %args ) = @_;
		    my( $repo, $eprint, $changed ) = @args{qw( repository dataobj changed )};
			$repo->call( "institution_browse_view_filter", $eprint );
		} );
	}
	elsif( defined $c->{institution_browse_view_config} )
	{
		$c->add_dataset_trigger( 'eprint', EPrints::Const::EP_TRIGGER_BEFORE_COMMIT, sub
		{
		    my( %args ) = @_;
		    my( $repo, $eprint, $changed ) = @args{qw( repository dataobj changed )};

			if( !defined $repo->config("institution_browse_view_config", "fields" ) )
			{
				$repo->log( "Institution browse view warning: browse field specified" );
				return;
			}		

			if( !defined $repo->config("institution_browse_view_config", "sub_field" ) )
			{
				$repo->log( "Institution browse view warning: no sub_field specified" );
				return;
			}		

			if( !defined $repo->config("institution_browse_view_config", "regex" ) )
			{
				$repo->log( "Institution browse view warning: no regex specified" );
				return;
			}		

			# standard set up
			my @fields = @{$repo->config( "institution_browse_view_config", "fields" )};
			my $sub_field = $repo->config("institution_browse_view_config", "sub_field" );
			my $regex = $repo->config("institution_browse_view_config", "regex" );

			my @browse_ids;
			my @browse_names;
	    	foreach my $field ( @fields )
			{
				foreach my $c ( @{$eprint->value( $field )} )
			    {
    		    	next unless defined $c->{name};
        			next unless defined $c->{$sub_field};
	        		next unless lc( $c->{$sub_field} ) =~ /$regex/;
					push @browse_ids, md5_hex($c->{$sub_field});
					push @browse_names, $c->{name};
				}
			}
			$eprint->set_value( "users_id", \@browse_ids );
			$eprint->set_value( "users_name", \@browse_names );
	    } );
	}
	else
	{
		print STDERR "Institution browse view warning: No means to identify instituional authors";
	}

	# and update the name rendering
	if( defined $c->{institution_browse_view_config} && defined $c->{institution_browse_view_config}->{fields} )
	{
		for my $field ( @{ $c->{fields}->{eprint} } )
		{			
			if( grep { $field->{name} eq $_ } @{$c->{institution_browse_view_config}->{fields}} )
			{
				$field->{render_value} = "render_name";
				$field->{browse_link} = $c->{institution_browse_view};
			}
		}
	}
}

no warnings 'uninitialized';

$c->{render_name} = sub
{
    my( $session, $field, $value ) = @_;

    my $repo = $session->get_repository();
    my $ds = $field->dataset;
    my $familylast = defined $field->{render_order} && $field->{render_order} eq "gf";
    my $frag = $repo->make_doc_fragment;

    my $creators = $value;
    $creators = [$creators] if(ref($creators) eq "HASH");
    my $max_creators = 10;

    my $more_span = $repo->make_element( "span", class => "citation_more" );

    my $count=0;
    for my $creator(@$creators){

        # is this the stage where we need to start hiding people away?
        if( $count == $max_creators )
        {
            $frag->appendChild( my $show_span = $repo->make_element( "span", class => "citation_more_link" ) );
            $show_span->appendChild( $repo->make_text( "+" . ( scalar @$creators - $max_creators ) . " more..." ) );
            $frag->appendChild( $more_span );
        }

        my $name = $creator->{name};

        # span container for name and one or two links (browse link + orcid link)
        my $span;
        if( defined $creator->{orcid} && $creator->{orcid} ne "" )
        {
            $span = $repo->make_element("span", class=>"person orcid-person");
        }
        else
        {
            $span = $repo->make_element("span", class=>"person");
        }

        # name text
        my $name_text;
        my $firstbit = "";
        if( defined $name->{honourific} && $name->{honourific} ne "" )
        {
            $firstbit = $name->{honourific}." ";
        }

        if( defined $name->{given} && $name->{given} ne "" )
        {
            # TODO: Rewrite the below regex to get up to three initials
            #$firstbit.= $name->{given};
            my $initials = $name->{given};
            $initials =~ s/^(\w)[^\s]*(|\s+(\w)[^\s]*(|\s+(\w)[^\s]*))$/$1$3$5/; #no more than 3 initials...
            my $citation_initials = $1.".";
            if( $3 ){ $citation_initials .= " ".$3."."};
            if( $5 ){ $citation_initials .= " ".$5."."};
            #$initials =~ s/^(\w)[^\s]*.*$/$1\./; #Only first initial required apparently...?
            $firstbit.= $citation_initials;
        }

        my $secondbit = "";
        if( defined $name->{family} )
        {
            $secondbit = $name->{family};
        }
        if( defined $name->{lineage} && $name->{lineage} ne "" )
        {
            $secondbit .= " ".$name->{lineage};
        }
        if( !length( $firstbit ) )
        {
            $name_text = $repo->make_text($secondbit);
        }
        elsif( defined $familylast && $familylast )
        {
            $name_text = $repo->make_text($firstbit." ".$secondbit);
        }
        else
        {
            $name_text = $repo->make_text($secondbit.", ".$firstbit);
        }

        if( defined $field->{browse_link} )
        {
            my $views = $session->config( "browse_views" );
            my $linkview;
            foreach my $view ( @{$views} )
            {
                if( $view->{id} eq $field->{browse_link} )
                {
                    $linkview = $view;			
                }
            }

            my $sub_field;
            foreach my $inner_field ( @{$field->{fields}} )
            {
                if( $inner_field->{sub_name} eq "name" )
                {
                    $sub_field = $field->name . "_" . $inner_field->{sub_name};
                    $sub_field = $ds->field( $sub_field );
                }
            }

            my $link_id;
	        if( defined $session->config("institution_browse_view_filter") )
            {
                # TO DO
            }
	        elsif( defined $session->config("institution_browse_view_config" ) )
        	{
                my $browse_sub_field = $repo->config("institution_browse_view_config", "sub_field" );
                my $regex = $repo->config("institution_browse_view_config", "regex" );
                if( EPrints::Utils::is_set( $creator->{$browse_sub_field} ) && 
                    lc($creator->{$browse_sub_field}) =~ /$regex/ )
                {
                    $link_id = md5_hex($creator->{$browse_sub_field});
                }

            }

            # we don't have a link... add the text as is to the span
            if(!defined $link_id || $link_id eq "")
            {
                $span->appendChild($name_text);
            }
            else
            {
                # we do have a link... create the link, add the name to it and add to the span
                my $url;
                if( (defined $linkview->{fields} && $linkview->{fields} =~ m/,/) ||
                    (defined $linkview->{menus} && scalar(@{$linkview->{menus}}) > 1)
                  )
                {
                    # has sub pages
                    $url .= "/view/".$field->{browse_link}."/".
                        EPrints::Utils::escape_filename( $link_id )."/";
                }
                else
                {
                    # no sub pages
                    $url .= "/view/".$field->{browse_link}."/".
                        EPrints::Utils::escape_filename( $link_id ).
                        ".html";
                }

                my $a = $session->make_element("a", href=>$url, class=>"citation_browse_link" );
                $a->appendChild( $name_text );
                $span->appendChild($a);
            }
        }
        else # no potential for browse link
        {
            $span->appendChild($name_text);
        }

        # ORCIDs!!!!
        if( defined $creator->{orcid} && $creator->{orcid} ne "" )
        {
            # create the orcid badge
            my $orcid = $creator->{orcid};
            my $orcid_link = $repo->make_element( "a", class=>"orcid", href=>"https://orcid.org/$orcid", target=>"_blank", 'aria-describedby'=>"tooltip-orcid--$orcid" );
            $orcid_link->appendChild( $repo->make_element( "img", "src"=>"/images/orcid_id.svg", class=>"orcid-icon", alt=>"ORCID logo" ) );
            $span->appendChild( $orcid_link );
        }

        # the span is complete...
        if( $count >= $max_creators )
        {
            $more_span->appendChild( $span );
            $more_span->appendChild($repo->html_phrase("lib/metafield:join_name")) if($count<(scalar(@$creators)-2));
            $more_span->appendChild($repo->make_text(" & ")) if($count==(scalar(@$creators)-2));
        }
        else
        {
            $frag->appendChild( $span );
            $frag->appendChild($repo->html_phrase("lib/metafield:join_name")) if($count<(scalar(@$creators)-2));
            $frag->appendChild($repo->make_text(" & ")) if($count==(scalar(@$creators)-2));
        }

        $count++;

    }

    return $frag;
};
