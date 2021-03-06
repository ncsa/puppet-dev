# Require python 3
import sys
if sys.version_info.major < 3:
    msg = "Requires python version 3; attempted with version '{}'".format( sys.version_info.major )
    raise UserWarning( msg )

# Configure logging
import logging
logfmt = '%(levelname)s:%(funcName)s[%(lineno)d] %(message)s'
#loglvl = logging.DEBUG
loglvl = logging.INFO
logging.basicConfig( level=loglvl, format=logfmt )

# Finish imports
import collections
import colored
import dashtable
import os
import pathlib
import pprint
import re
import subprocess
import yaml

# Custom type for R10K source data
R10KSrc = collections.namedtuple( 'R10KSrc', ['basedir', 'environments', 'remote'] )

# Hash to hold module level (global) data
resources = {}


def get_repo_names():
    key = 'repo_names'
    if key not in resources:
        val = None
        # try environment variable
        rawstr = os.getenv( 'REPO_NAMES' )
        if rawstr:
            val = [ v for v in rawstr.split() ]
        else:
            val = get_r10k_sources().keys()
        if not val:
            msg = 'Unable to get repo names. Try setting REPO_NAMES env var.'
            logging.error( msg )
            raise SystemExit( msg )
        resources[ key ] = val
    return resources[ key ]


def get_r10k_sources():
    ''' Get R10K deploy display YAML output
    '''
    key = 'r10k_sources'
    if key not in resources:
        sources = {}
        cmd = [ '/opt/puppetlabs/puppet/bin/r10k', 'deploy', 'display' ]
        proc = subprocess.run( cmd, 
                               stdout=subprocess.PIPE,
                               stderr=subprocess.PIPE, 
                               check=True,
                               timeout=30
                             )
        data = yaml.safe_load( proc.stdout )
        logging.debug( 'Raw Data:\n{}\n'.format( pprint.pformat( data ) ) )
        # create r10k resource list
        for s in data[':sources']:
            name = s[':name'].strip(':')
            basedir = s[':basedir'].strip(':')
            remote = s[':remote'].strip(':')
            sources[name] = R10KSrc( basedir=pathlib.Path( basedir ),
                                     environments=s[':environments'],
                                     remote=remote )
        logging.debug( "SOURCES:\n{}\n".format( pprint.pformat( sources ) ) )
        resources[ key ] = sources
    return resources[ key ]


def get_reference_branches():
    key = 'reference_branch_names'
    if key not in resources:
        val = None
        rawstr = os.getenv( 'REFERENCE_NAMES' )
        if rawstr:
            val = [ v for v in rawstr.split() ]
        else:
            msg = 'Unable to get reference names. Try setting REFERENCE_NAMES env var.'
            logging.error( msg )
            raise SystemExit( msg )
        resources[ key ] = val
    return resources[ key ]


def get_topic_keyword():
    key = 'topic_keyword'
    if key not in resources:
        val = os.getenv( 'TOPIC_KEYWORD', None )
        if not val:
            msg = 'Unable to get topic keyword. Try setting TOPIC_KEYWORD env var.'
            logging.error( msg )
            raise SystemExit( msg )
        resources[ key ] = val
    return resources[ key ]


def get_puppet_dir():
    key = 'puppet_dir'
    if key not in resources:
        resources[ key ] = pathlib.Path.home() / 'puppet'
    return resources[ key ]


def get_topics_merge_status( repo, branch ):
    ''' cd to REPO, get list of branches merged & notmerged to BRANCH
        Return: { 'merged': <list of branch names>
                  'notmerged': <list of branch names> }
    '''
    repodir = get_puppet_dir() / repo
    # Update local repo information
    git( 'remote update origin --prune', repodir )
    # merged
    proc = git( f'branch -r --merged remotes/origin/{branch}', repodir )
    lines = proc.stdout.decode().splitlines()
    logging.debug( f'{repo} {branch} merged raw: {pprint.pformat( lines )}' )
    merged = filter_non_topic_branches( lines )
    logging.debug( f'{repo} {branch} merged: {pprint.pformat( merged )}' )
    # not merged
    proc = git( f'branch -r --no-merged remotes/origin/{branch}', repodir )
    lines = proc.stdout.decode().splitlines()
    logging.debug( f'{repo} {branch} notmerged raw: {pprint.pformat( lines )}' )
    notmerged = filter_non_topic_branches( lines )
    logging.debug( f'{repo} {branch} notmerged: {pprint.pformat( notmerged )}' )
    return { 'merged': merged, 'notmerged': notmerged, }


def filter_non_topic_branches( lines ):
    r = 'remotes/'
    o = 'origin/'
    topic_keyword = get_topic_keyword()
    parts = set()
    for line in lines:
        if topic_keyword in line:
            parts.add( line.strip().replace(r,'').replace(o,'') )
    return parts


def git( rawcmd, cwd ):
    cmd = [ 'git' ] + rawcmd.split()
    try:
        proc = subprocess.run( cmd,
                               cwd     = cwd,
                               stdout  = subprocess.PIPE,
                               stderr  = subprocess.PIPE,
                               check   = True,
                               timeout = 10,
                             )
    except ( subprocess.CalledProcessError ) as e:
        logging.error( e.stderr )
        raise e
    return proc


def run():
    repos = get_repo_names()
    branches = get_reference_branches()
    # Get all statuses and list of unique topics
    statuses = {}
    topics = []
    for repo in repos:
        statuses[ repo ] = {}
        for branch in branches:
            status = get_topics_merge_status( repo, branch )
            statuses[ repo ][ branch ] = status
            for state in [ 'merged', 'notmerged' ]:
                for topic in status[ state ]:
                    topics.append( topic )
    topics = list( set( topics ) )
    logging.debug( f'data:\n{pprint.pformat(statuses)}' )
    logging.debug( f'topics:\n{pprint.pformat(topics)}' )
    
    # Colored output settings
    repo_colors = [ 
                    colored.fg(0) + colored.bg(7),
                    colored.fg(0) + colored.bg('cyan'),
                    colored.fg(0) + colored.bg(208),
                    colored.fg(15) + colored.bg(63),
                    colored.fg(7) + colored.bg(21),
                    colored.fg(0) + colored.bg(229),
                    colored.fg(0) + colored.bg(221),
                    colored.fg(0) + colored.bg(214),
                    colored.fg(0) + colored.bg(208),
                  ]
    yes_color = colored.stylize( ' Yes ', colored.fg('green') )
    no_color = colored.stylize( ' No ', colored.fg('red') )

    # Create data rows for output
    # Row format is:
    #       CONTROL   HIERA     LEGACY
    # 0     1    2    3    4    5    6
    # topic prod test prod test prod test
    br_max_len = 4
    br_hdrs = [ b[:br_max_len].upper() for b in branches ]
    hdr_row_2 = [ 'TOPIC' ]
    [ hdr_row_2.extend( br_hdrs ) for r in repos ]
    #rows = []
    rows = [ hdr_row_2 ]
    max_topic_len = 0
    for topic in sorted( topics ):
        rownum = len( rows )
        if len( topic ) > max_topic_len:
            max_topic_len = len( topic )
        row = [ topic ]
        for repo in repos:
            for branch in branches:
                colnum = len( row )
                val = '-'
                if topic in statuses[repo][branch]['merged']:
                    #val = yes
                    val = 'Yes'
                elif topic in statuses[repo][branch]['notmerged']:
                    #val = no
                    val = 'No'
                row.append( val )
        rows.append( row )

    # Make repo header row
    pad_len = 2 #cell padding size
    sep_len = 2 #column separator size
    sep = ' ' * sep_len
    hdr_row_1 = [ '' ]
    for i,r in enumerate(repos):
        hdr_row_1.append( r.upper() )
        for b in branches[1:]:
            hdr_row_1.append( '' )

    rows.insert( 0, hdr_row_1 )

    table_params = {
        'use_headers': True,
        'center_cells': False,
        'center_headers': True,
    }
       
    # colspans are directly related to number of branches and number of repos
    num_branches = len( branches )
    if num_branches > 1:
        spanlist = []
        for repo_iter in range( len( repos ) ):
            cells = []
            for br_iter in range( 1, num_branches + 1 ):
                colnum = repo_iter * num_branches + br_iter
                cells.append( [0,colnum] )
            spanlist.append( cells )
        table_params[ 'spans' ] = spanlist
        table_params['spans'] = spanlist
    text_table = dashtable.data2rst( rows, **table_params )

    # Attempt to replace plain strings with colorized versions
    text_table = text_table.replace( ' Yes ', yes_color )
    text_table = text_table.replace( ' No ', no_color )
    for i,r in enumerate(repos):
        R = r.upper()
        pattern = f'\|( +{R} +)\|'
        match = re.search( pattern, text_table )
        if match:
            old = match.group(1)
            new = colored.stylize( old, repo_colors[i] )
            text_table = text_table.replace( old, new )

    # Remove column markers
    text_table = text_table.replace( '|', ' ' )

    # Unindent everything
    lines = text_table.splitlines()
    lines = [ l[2:] for l in lines ]

    # Save last line to use as header demark
    demark_line = lines.pop()
    demark_line = demark_line.replace( '+', ' ' )

    # Remove non-content lines
    lines = [ l for l in lines if ' ' in l ]

    # Add in demark line
    lines.insert( 2, demark_line )

    print( '\n'.join( lines ) )

if __name__ == '__main__':
    run()
