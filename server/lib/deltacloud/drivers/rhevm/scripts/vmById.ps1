#
# Copyright (C) 2009  Red Hat, Inc.
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) any later version.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA

param([string]$scriptsDir,
        [string]$username,
        [string]$password,
        [string]$domain,
        [string]$id)
# Get the common functions
. "$scriptsDir\common.ps1"
verifyLogin $username $password $domain
$vm = get-vm $id
beginOutput
# The AppliacationList causes the YAML pain, so Omit it
$vm | format-list -Property $VM_PROPERTY_LIST
endOutput