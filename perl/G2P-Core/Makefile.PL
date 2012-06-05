use 5.014002;
use ExtUtils::MakeMaker;

my %g2p_info;

sub default_g2p_lib {
    if ( $^O eq 'MSWin32' ) {
        $g2p_info{libs} = '-lWinG2PDLL';
    }
    else {
        $g2p_info{libs} = '-lg2p';
    }
}

if ( eval "use ExtUtils::PkgConfig; 1" ) {
    require ExtUtils::PkgConfig;

    eval {
        my $package = 'libg2p';

        %g2p_info = ExtUtils::PkgConfig->find($package);

        if ( $^O eq 'MSWin32' ) {
            my @libs_dirs = split( /\s*-L/, ExtUtils::PkgConfig->libs_only_L($package) );

            foreach my $dir ( @libs_dirs ) {
                next if ( $dir =~ /^\s*$/ );

                # XXX: On Win32 ExtUtils::PkgConfig (or perhaps pkg-config itself)
                #      do not do proper EOL conversions, so \r do not get stripped.
                $dir =~ s/^\s*//;
                $dir =~ s/\s*$//;

                if ( ! -e "$dir/libg2p.a" && -e "$dir/libg2p.dll.a" ) {
                    # XXX: MakeMaker only handle static library names.
                    $g2p_info{libs} =~ s/(\-lg2p)\b/$1.dll/;

                    last;
                }
                elsif ( -e "$dir/libg2p.a" ) {
                    # XXX: Need to fixup the imports for a static library.
                    $g2p_info{cflags} .= ' -DLIBG2P_STATIC';

                    last;
                }
            }
        }
    };
    if ($@) {
        warn $@;
        default_g2p_lib();
    }
}
else {
    warn "ExtUtils::PkgConfig not found, trying defaults";
    default_g2p_lib();
}

#$g2p_info{libs} .= ' -lmsvcrtd -lmsvcprtd';
#$g2p_info{libs} .= ' -lmsvcrtd';
#$g2p_info{cflags} .= ' -MDd';

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'G2P::Core',
    VERSION_FROM      => 'lib/G2P/Core.pm', # finds $VERSION
    PREREQ_PM         => {}, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/G2P/Core.pm', # retrieve abstract from module
       AUTHOR         => 'Martin Schlemmer <mschlemmer.ctxt@gmail.com>') : ()),
    LIBS              => [ $g2p_info{libs} ], # e.g., '-lm'
    DEFINE            => '-D_UNICODE -DUNICODE', # e.g., '-DHAVE_SOMETHING'
#    OPTIMIZE          => $g2p_info{cflags}, # e.g., '-lm'
    INC               => '-I. ' . $g2p_info{cflags}, # e.g., '-I. -I/usr/include/other'
    # Un-comment this if you add C files to link with later:
    # OBJECT            => '$(O_FILES)', # link all the C files too
    XSPROTOARG        => '-noprototypes',
    XSOPT             => '-C++',
);
