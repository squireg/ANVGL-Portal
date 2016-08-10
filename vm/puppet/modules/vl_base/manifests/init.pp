# Installs the base utilities required for a VL job image. Any dependencies
# required for a given solution will be layered on top of this base at runtime.
#
# TODO: Provide environments for different OS flavours (e.g. Debian or Redhat)
# and Python major versions (2.x, 3.x).
#

include epel
include puppi

class vl_base {
  # Make sure we have curl/wget for job up/down-loads.
  ensure_packages(['curl', 'wget'])

  # Install at for walltime monitoring
  ensure_packages(['at'])

  # Should we install dev essentials, on the assumption that we'll need to
  # install python modules using pip?
}
