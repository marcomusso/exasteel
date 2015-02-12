package Exasteel::Controller::Public_API;

use Mojo::Base 'Mojolicious::Controller';
use Mojo::Log;
use Data::Dumper;
use DateTime;
use POSIX qw(strftime);

# render static docs
sub docs {
  my $self = shift;
  $self->render('api/v1/docs');
}

=head1 Exasteel API v1

This are the public API for Exasteel. You can call every method via an HTTP GET:

	http://<EXASTEEL_URL>/api/v1/<method>/<parameters...>

Example:

	http://<EXASTEEL_URL>/api/v1/vdckpi/<KPI>.csv

The HTTP response will be according to the extension requested (mostly supported: CSV and JSON).

Method list:

=head2 vdckpi

TBD

=cut
sub VDCKPI {
  my $self=shift;
  my $db=$self->db;
  my $log=$self->public_api_log;
  my $log_level=2;

  my %hash=();
  my $csv_data='';

	my $ua=$self->req->headers->user_agent;
	my $ip=$self->tx->remote_address;
	if ($log_level>0) {
    my $user='';
    if ($self->session->{login} and $self->session->{login} ne '') {
      $user=' (logged user: '.$self->session->{login}.')';
    }
    $log->debug("Exasteel::Controller::Public_API::vdckpi | Request by $ua @ $ip".$user);
	}

  # get config from db

	$self->respond_to(
	  json =>	{ json => \%hash },
	  csv  =>	{ text => $csv_data }
	);
}

=head2 VDCAccounts

Returns the accounts defined in the VDC (basically a conversion from XML to JSON :).

You call this method like:

  /api/v1/vdcaccounts/<vdc>.json

Example:

  # curl "http://<EXASTEEL_URL>/api/v1/vdcaccounts/EL01.json"
  {
    "TEMPLATES": {
      "id": "ACC-00000000-0000-0000-0000-000000000000",
      "description": "Public templates"
    },
    "DEV": {
      "id": "ACC-00000000-0000-0000-0000-000000000000",
      "description": ""
    },
    "MANAGEMENT": {
      "description": "Management account",
      "id": "ACC-00000000-0000-0000-0000-000000000000"
    },
    "PERFORMANCE-TEST": {
      "id": "ACC-00000000-0000-0000-0000-000000000000",
      "description": "For performance testing vm"
    },
    "TEST": {
      "id": "ACC-00000000-0000-0000-0000-000000000000",
      "description": ""
    }
  }

=cut
sub VDCAccounts {
  my $self=shift;
  my $db=$self->db;
  my $log=$self->public_api_log;
  my $log_level=$self->log_level;
  my $vdc=$self->param('vdc');

  my $ua=$self->req->headers->user_agent;
  my $ip=$self->tx->remote_address;
  $log->debug("Exasteel::Controller::Public_API::VDCAccounts | Request by $ua @ $ip") if $log_level>0;

  my $emoc_ua = Mojo::UserAgent->new;

  my $now=time()*1000;      # I need millisecs
  my $expires=$now+600000;  # let's double the minimum according to http://docs.oracle.com/cd/E27363_01/doc.121/e25150/appendix.htm#OPCAC936

  # lookup vdc config ($username, $password, $emoc_endpoint) in mongodb
  my $vdcs_collection=$self->db->get_collection('vdcs');
  my $find_result=$vdcs_collection->find({"display_name" => $vdc});
  my @vdcs=$find_result->all;

  if (@vdcs) {
    $log->debug("Exasteel::Controller::Public_API::VDCAccounts | Found vDC: ".Dumper(@vdcs)) if $log_level>1;
  }

  my $username=$vdcs[0]{emoc_username};
  my $password=$vdcs[0]{emoc_password};
  my $emoc_endpoint=$vdcs[0]{emoc_endpoint};
  # TODO further sanitize endpoint, ie no http, no URI part, only hostname:port
  $emoc_endpoint=~s/http[s]:\/\///g;
  my %accounts=();

  my $url='https://'.$username.':'.$password.'@'.$emoc_endpoint.'/akm/?Action=DescribeAccounts&Version=1&Timestamp='.$now.'&Expires='.$expires;

  $log->debug("Exasteel::Controller::Public_API::VDCAccounts | URL: ".$url) if $log_level>1;

  my $data=$emoc_ua->get($url);
  if (my $res = $data->success) {
    # force XML semantics
    $res->dom->xml(1);
    $res->dom->find('items')->each(
      sub {
        my $account_id='';
        my $account_name='';
        my $account_description='';
        if ($_->at('account')) { $account_id=$_->at('account')->text; }
        if ($_->at('name')) { $account_name=$_->at('name')->text; }
        if ($_->at('description')) {
          $account_description = $_->at('description')->text;
        }
        $accounts{$account_name}={
          "id" => $account_id,
          "description" => $account_description
        };
      }
    );
  } else {
    $log->debug("Exasteel::Controller::Public_API::VDCAccounts | Error in request to EMOC");
    $accounts{'status'}="ERROR";
    $accounts{'description'}="Error in request to EMOC";
  }

  if ($log_level>0) {
    $log->debug("Exasteel::Controller::Public_API::VDCAccounts | Result: ".Dumper(\%accounts));
  }

  # TODO check for errors

  $self->respond_to(
    json => { json => \%accounts }
  );
}

=head2 getAllInfo

Returns all info

You call this method like:

  /api/v1/getallinfo/<vdc>.json

Example:

  # curl "http://<EXASTEEL_URL>/api/v1/getallinfo/EL01.json"

=cut
sub getAllInfo {
  my $self=shift;
  my $db=$self->db;
  my $log=$self->public_api_log;
  my $log_level=$self->log_level;
  my $vdc=$self->param('vdc_name');
  my %status=(status => 'OK', description => '' );

  my $ua=$self->req->headers->user_agent;
  my $ip=$self->tx->remote_address;
  $log->debug("Exasteel::Controller::Public_API::getAllInfo | Request by $ua @ $ip") if $log_level>0;

  # curl -k --basic  --user admin:welcome1 https://10.248.192.176:7002/ovm/core/wsapi/rest/ServerPool
  # <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
  # <servers>
  #   <server>
  #     <generation>192</generation>
  #     <id>
  #       <name>el01-cn04.sede.corp.sanpaoloimi.com</name>
  #       <type>com.oracle.ovm.mgr.ws.model.Server</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/Server/e0:24:47:ba:00:10:ff:ff:ff:ff:ff:ff:ff:20:00:08</uri>
  #       <value>e0:24:47:ba:00:10:ff:ff:ff:ff:ff:ff:ff:20:00:08</value>
  #     </id>
  #     <locked>false</locked>
  #     <name>el01-cn04.sede.corp.sanpaoloimi.com</name>
  #     <abilityMap>
  #       <entry>
  #         <key>iSCSI</key>
  #         <value>true</value>
  #       </entry>
  #       <entry>
  #         <key>Fibre Channel</key>
  #         <value>true</value>
  #       </entry>
  #       <entry>
  #         <key>Memory Alignment</key>
  #         <value>1048576</value>
  #       </entry>
  #       <entry>
  #         <key>Bond Mode Active Backup</key>
  #         <value>true</value>
  #       </entry>
  #       <entry>
  #         <key>Bond Mode Adaptive Load Balancing</key>
  #         <value>true</value>
  #       </entry>
  #       <entry>
  #         <key>Clusters</key>
  #         <value>true</value>
  #       </entry>
  #       <entry>
  #         <key>High Availability</key>
  #         <value>true</value>
  #       </entry>
  #       <entry>
  #         <key>Power on WOL</key>
  #         <value>true</value>
  #       </entry>
  #       <entry>
  #         <key>Migration Setup</key>
  #         <value>false</value>
  #       </entry>
  #       <entry>
  #         <key>NFS</key>
  #         <value>true</value>
  #       </entry>
  #       <entry>
  #         <key>YUM update</key>
  #         <value>true</value>
  #       </entry>
  #       <entry>
  #         <key>VNC Console</key>
  #         <value>true</value>
  #       </entry>
  #       <entry>
  #         <key>Serial Console</key>
  #         <value>true</value>
  #       </entry>
  #       <entry>
  #         <key>MTU Configuration</key>
  #         <value>true</value>
  #       </entry>
  #       <entry>
  #         <key>VM Suspend</key>
  #         <value>true</value>
  #       </entry>
  #       <entry>
  #         <key>Per-VM CPU Over-subscription</key>
  #         <value>true</value>
  #       </entry>
  #       <entry>
  #         <key>Maximum number of VNICS for HVM</key>
  #         <value>8</value>
  #       </entry>
  #       <entry>
  #         <key>Local Storage Element</key>
  #         <value>true</value>
  #       </entry>
  #       <entry>
  #         <key>Bond Mode Link Aggregation</key>
  #         <value>true</value>
  #       </entry>
  #       <entry>
  #         <key>All-VM CPU Over-subscription</key>
  #         <value>true</value>
  #       </entry>
  #     </abilityMap>
  #     <agentLogin>oracle</agentLogin>
  #     <agentPort>8899</agentPort>
  #     <biosReleaseDate>06/19/2012</biosReleaseDate>
  #     <biosVendor>American Megatrends Inc.</biosVendor>
  #     <biosVersion>17021300</biosVersion>
  #     <clusterId>
  #       <type>com.oracle.ovm.mgr.ws.model.Cluster</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/Cluster/f9734a05404f4a13</uri>
  #       <value>f9734a05404f4a13</value>
  #     </clusterId>
  #     <controlDomains>
  #       <agentVersion>3.2.1-183</agentVersion>
  #       <cpuCount>32</cpuCount>
  #       <memory>7168</memory>
  #       <osKernelRelease>2.6.39-300.22.2.el5uek</osKernelRelease>
  #       <osKernelVersion>#1 SMP Fri Jan 4 12:40:29 PST 2013</osKernelVersion>
  #       <osMajorVersion>5</osMajorVersion>
  #       <osMinorVersion>7</osMinorVersion>
  #       <osName>Oracle VM Server</osName>
  #       <osType>Linux</osType>
  #       <ovmVersion>3.2.1-517</ovmVersion>
  #       <rpmVersion>3.2.1-183</rpmVersion>
  #     </controlDomains>
  #     <coresPerProcessorSocket>8</coresPerProcessorSocket>
  #     <cpuArchitectureType>X86_64</cpuArchitectureType>
  #     <cpuCompatibilityGroupId>
  #       <name>Default_Intel_Family:6_Model:45</name>
  #       <type>com.oracle.ovm.mgr.ws.model.CpuCompatibilityGroup</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/CpuCompatibilityGroup/Default_Intel_F6_M45</uri>
  #       <value>Default_Intel_F6_M45</value>
  #     </cpuCompatibilityGroupId>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>1</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>2</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>3</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>4</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>5</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>6</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>7</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>8</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>9</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>10</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>11</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>12</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>13</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>14</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>15</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>16</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>17</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>18</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>19</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>20</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>21</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>22</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>23</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>24</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>25</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>26</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>27</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>28</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>29</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>30</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>31</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>32</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <enabledProcessorCores>16</enabledProcessorCores>
  #     <ethernetPortIds>
  #       <name>bond0 on el01-cn04.sede.corp.sanpaoloimi.com</name>
  #       <type>com.oracle.ovm.mgr.ws.model.EthernetPort</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/EthernetPort/0004fb0000200000a3f76bd4b7e0e25f</uri>
  #       <value>0004fb0000200000a3f76bd4b7e0e25f</value>
  #     </ethernetPortIds>
  #     <ethernetPortIds>
  #       <name>bond1 on el01-cn04.sede.corp.sanpaoloimi.com</name>
  #       <type>com.oracle.ovm.mgr.ws.model.EthernetPort</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/EthernetPort/0004fb000020000086d41349a2cdda9a</uri>
  #       <value>0004fb000020000086d41349a2cdda9a</value>
  #     </ethernetPortIds>
  #     <ethernetPortIds>
  #       <name>bond2 on el01-cn04.sede.corp.sanpaoloimi.com</name>
  #       <type>com.oracle.ovm.mgr.ws.model.EthernetPort</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/EthernetPort/0004fb00002000002fcdfe372dee9264</uri>
  #       <value>0004fb00002000002fcdfe372dee9264</value>
  #     </ethernetPortIds>
  #     <ethernetPortIds>
  #       <name>bond3 on el01-cn04.sede.corp.sanpaoloimi.com</name>
  #       <type>com.oracle.ovm.mgr.ws.model.EthernetPort</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/EthernetPort/0004fb00002000005ba3774beaafd1d9</uri>
  #       <value>0004fb00002000005ba3774beaafd1d9</value>
  #     </ethernetPortIds>
  #     <ethernetPortIds>
  #       <name>bond7 on el01-cn04.sede.corp.sanpaoloimi.com</name>
  #       <type>com.oracle.ovm.mgr.ws.model.EthernetPort</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/EthernetPort/0004fb0000200000a2bdbec257d1fe11</uri>
  #       <value>0004fb0000200000a2bdbec257d1fe11</value>
  #     </ethernetPortIds>
  #     <ethernetPortIds>
  #       <name>bond8 on el01-cn04.sede.corp.sanpaoloimi.com</name>
  #       <type>com.oracle.ovm.mgr.ws.model.EthernetPort</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/EthernetPort/0004fb0000200000add88f93a3cbac8f</uri>
  #       <value>0004fb0000200000add88f93a3cbac8f</value>
  #     </ethernetPortIds>
  #     <ethernetPortIds>
  #       <name>bond9 on el01-cn04.sede.corp.sanpaoloimi.com</name>
  #       <type>com.oracle.ovm.mgr.ws.model.EthernetPort</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/EthernetPort/0004fb00002000004d259200ba40584f</uri>
  #       <value>0004fb00002000004d259200ba40584f</value>
  #     </ethernetPortIds>
  #     <ethernetPortIds>
  #       <name>eth0 on el01-cn04.sede.corp.sanpaoloimi.com</name>
  #       <type>com.oracle.ovm.mgr.ws.model.EthernetPort</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/EthernetPort/0004fb0000200000b092680e63363bdd</uri>
  #       <value>0004fb0000200000b092680e63363bdd</value>
  #     </ethernetPortIds>
  #     <ethernetPortIds>
  #       <name>eth1 on el01-cn04.sede.corp.sanpaoloimi.com</name>
  #       <type>com.oracle.ovm.mgr.ws.model.EthernetPort</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/EthernetPort/0004fb0000200000f4e390e107e0b112</uri>
  #       <value>0004fb0000200000f4e390e107e0b112</value>
  #     </ethernetPortIds>
  #     <ethernetPortIds>
  #       <name>eth2 on el01-cn04.sede.corp.sanpaoloimi.com</name>
  #       <type>com.oracle.ovm.mgr.ws.model.EthernetPort</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/EthernetPort/0004fb0000200000e8c4a30a333f0984</uri>
  #       <value>0004fb0000200000e8c4a30a333f0984</value>
  #     </ethernetPortIds>
  #     <ethernetPortIds>
  #       <name>eth3 on el01-cn04.sede.corp.sanpaoloimi.com</name>
  #       <type>com.oracle.ovm.mgr.ws.model.EthernetPort</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/EthernetPort/0004fb000020000020f946fccb473568</uri>
  #       <value>0004fb000020000020f946fccb473568</value>
  #     </ethernetPortIds>
  #     <fileServerPluginIds>
  #       <name>Oracle OCFS2 File system</name>
  #       <type>com.oracle.ovm.mgr.ws.model.FileServerPlugin</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/FileServerPlugin/oracle.ocfs2.OCFS2.OCFS2Plugin%20(0.1.0-38)</uri>
  #       <value>oracle.ocfs2.OCFS2.OCFS2Plugin (0.1.0-38)</value>
  #     </fileServerPluginIds>
  #     <fileServerPluginIds>
  #       <name>Oracle Generic Network File System</name>
  #       <type>com.oracle.ovm.mgr.ws.model.FileServerPlugin</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/FileServerPlugin/oracle.generic.NFSPlugin.GenericNFSPlugin%20(1.1.0)</uri>
  #       <value>oracle.generic.NFSPlugin.GenericNFSPlugin (1.1.0)</value>
  #     </fileServerPluginIds>
  #     <fileSystemMountIds>
  #       <name>el01-cn04.sede.corp.sanpaoloimi.com_/OVS/Repositories/0004fb00000300008c29cbcc1a7781c0</name>
  #       <type>com.oracle.ovm.mgr.ws.model.FileSystemMount</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/FileSystemMount/e0:24:47:ba:00:10:ff:ff:ff:ff:ff:ff:ff:20:00:08_mount_%2FOVS%2FRepositories%2F0004fb00000300008c29cbcc1a7781c0</uri>
  #       <value>e0:24:47:ba:00:10:ff:ff:ff:ff:ff:ff:ff:20:00:08_mount_/OVS/Repositories/0004fb00000300008c29cbcc1a7781c0</value>
  #     </fileSystemMountIds>
  #     <haltOnError>false</haltOnError>
  #     <hostname>el01-cn04.sede.corp.sanpaoloimi.com</hostname>
  #     <hypervisor>
  #       <capabilities>XEN_3_0_PVM_x86_64</capabilities>
  #       <capabilities>XEN_3_0_PVM_x86_32</capabilities>
  #       <capabilities>XEN_3_0_HVM_x86_32</capabilities>
  #       <capabilities>XEN_3_0_HVM_x86_32_PAE</capabilities>
  #       <capabilities>XEN_3_0_HVM_x86_64</capabilities>
  #       <type>XEN</type>
  #       <version>4.1.3OVM</version>
  #     </hypervisor>
  #     <localStorageArrayId>
  #       <name>Generic Local Storage Array @ el01-cn04.sede.corp.sanpaoloimi.com</name>
  #       <type>com.oracle.ovm.mgr.ws.model.StorageArray</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/StorageArray/0004fb000009000030db62fdeb44d394</uri>
  #       <value>0004fb000009000030db62fdeb44d394</value>
  #     </localStorageArrayId>
  #     <maintenanceMode>false</maintenanceMode>
  #     <managerUuid>0004fb000001000048baef3bcc606861</managerUuid>
  #     <manufacturer>Oracle Corporation</manufacturer>
  #     <memory>262133</memory>
  #     <noExecuteFlag>true</noExecuteFlag>
  #     <ntpServers>10.254.250.1</ntpServers>
  #     <ntpServers>10.254.250.4</ntpServers>
  #     <ntpServers>10.254.250.5</ntpServers>
  #     <ovmVersion>3.2.1-517</ovmVersion>
  #     <populatedProcessorSockets>2</populatedProcessorSockets>
  #     <processorSpeed>2893094.0</processorSpeed>
  #     <productName>SUN FIRE X4170 M3</productName>
  #     <productSerialNumber>1249FML0P7</productSerialNumber>
  #     <runVmsEnabled>true</runVmsEnabled>
  #     <serverPoolId>
  #       <name>el01Pool1</name>
  #       <type>com.oracle.ovm.mgr.ws.model.ServerPool</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/ServerPool/0004fb0000020000f9734a05404f4a13</uri>
  #       <value>0004fb0000020000f9734a05404f4a13</value>
  #     </serverPoolId>
  #     <serverRoles>UTILITY</serverRoles>
  #     <serverRoles>VM</serverRoles>
  #     <serverRunState>RUNNING</serverRunState>
  #     <statisticInterval>20</statisticInterval>
  #     <storageArrayPluginIds>
  #       <name>Sun ZFS Storage Appliance iSCSI/FC1.0.2-58</name>
  #       <type>com.oracle.ovm.mgr.ws.model.StorageArrayPlugin</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/StorageArrayPlugin/oracle.s7k.SCSIPlugin.SCSIPlugin%20(1.0.2-58)</uri>
  #       <value>oracle.s7k.SCSIPlugin.SCSIPlugin (1.0.2-58)</value>
  #     </storageArrayPluginIds>
  #     <storageArrayPluginIds>
  #       <name>Oracle Generic SCSI Plugin</name>
  #       <type>com.oracle.ovm.mgr.ws.model.StorageArrayPlugin</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/StorageArrayPlugin/oracle.generic.SCSIPlugin.GenericPlugin%20(1.1.0)</uri>
  #       <value>oracle.generic.SCSIPlugin.GenericPlugin (1.1.0)</value>
  #     </storageArrayPluginIds>
  #     <storageInitiatorIds>
  #       <type>com.oracle.ovm.mgr.ws.model.StorageInitiator</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/StorageInitiator/iqn.1988-12.com.oracle:ec86a92d6644</uri>
  #       <value>iqn.1988-12.com.oracle:ec86a92d6644</value>
  #     </storageInitiatorIds>
  #     <storageInitiatorIds>
  #       <type>com.oracle.ovm.mgr.ws.model.StorageInitiator</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/StorageInitiator/storage.LocalStorageInitiator%20in%20e0:24:47:ba:00:10:ff:ff:ff:ff:ff:ff:ff:20:00:08</uri>
  #       <value>storage.LocalStorageInitiator in e0:24:47:ba:00:10:ff:ff:ff:ff:ff:ff:ff:20:00:08</value>
  #     </storageInitiatorIds>
  #     <threadsPerCore>2</threadsPerCore>
  #     <totalProcessorCores>16</totalProcessorCores>
  #     <usableMemory>127579</usableMemory>
  #     <vmIds>
  #       <name>sapvxp070</name>
  #       <type>com.oracle.ovm.mgr.ws.model.Vm</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/Vm/0004fb00000600005fdfaa38fc74b1fa</uri>
  #       <value>0004fb00000600005fdfaa38fc74b1fa</value>
  #     </vmIds>
  #     <vmIds>
  #       <name>sapvxp013</name>
  #       <type>com.oracle.ovm.mgr.ws.model.Vm</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/Vm/0004fb0000060000870679efd00eda44</uri>
  #       <value>0004fb0000060000870679efd00eda44</value>
  #     </vmIds>
  #     <vmIds>
  #       <name>sapvxp015</name>
  #       <type>com.oracle.ovm.mgr.ws.model.Vm</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/Vm/0004fb00000600009e21cc16dc2e20ab</uri>
  #       <value>0004fb00000600009e21cc16dc2e20ab</value>
  #     </vmIds>
  #     <vmIds>
  #       <name>sapvxp018</name>
  #       <type>com.oracle.ovm.mgr.ws.model.Vm</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/Vm/0004fb000006000080fa34a8d8b9644a</uri>
  #       <value>0004fb000006000080fa34a8d8b9644a</value>
  #     </vmIds>
  #     <vmIds>
  #       <name>sapvxp022</name>
  #       <type>com.oracle.ovm.mgr.ws.model.Vm</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/Vm/0004fb0000060000f1721cd106732f80</uri>
  #       <value>0004fb0000060000f1721cd106732f80</value>
  #     </vmIds>
  #     <vmIds>
  #       <name>sapvxp026</name>
  #       <type>com.oracle.ovm.mgr.ws.model.Vm</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/Vm/0004fb0000060000fdbf74824cf2375c</uri>
  #       <value>0004fb0000060000fdbf74824cf2375c</value>
  #     </vmIds>
  #     <vmIds>
  #       <name>sapvxp030</name>
  #       <type>com.oracle.ovm.mgr.ws.model.Vm</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/Vm/0004fb0000060000425bd8c2d7c4443a</uri>
  #       <value>0004fb0000060000425bd8c2d7c4443a</value>
  #     </vmIds>
  #     <vmIds>
  #       <name>sapvxp034</name>
  #       <type>com.oracle.ovm.mgr.ws.model.Vm</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/Vm/0004fb00000600005a1c66b9728b378b</uri>
  #       <value>0004fb00000600005a1c66b9728b378b</value>
  #     </vmIds>
  #     <vmIds>
  #       <name>sapvxp046</name>
  #       <type>com.oracle.ovm.mgr.ws.model.Vm</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/Vm/0004fb0000060000af1d602a632dfc66</uri>
  #       <value>0004fb0000060000af1d602a632dfc66</value>
  #     </vmIds>
  #     <vmIds>
  #       <name>sapvxp050</name>
  #       <type>com.oracle.ovm.mgr.ws.model.Vm</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/Vm/0004fb00000600009283f548bf5131e6</uri>
  #       <value>0004fb00000600009283f548bf5131e6</value>
  #     </vmIds>
  #     <vmIds>
  #       <name>sapvxp054</name>
  #       <type>com.oracle.ovm.mgr.ws.model.Vm</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/Vm/0004fb0000060000555a24e6f55fa227</uri>
  #       <value>0004fb0000060000555a24e6f55fa227</value>
  #     </vmIds>
  #     <vmIds>
  #       <name>sapvxp038</name>
  #       <type>com.oracle.ovm.mgr.ws.model.Vm</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/Vm/0004fb00000600008d937588880797e4</uri>
  #       <value>0004fb00000600008d937588880797e4</value>
  #     </vmIds>
  #     <vmIds>
  #       <name>sapvxp042</name>
  #       <type>com.oracle.ovm.mgr.ws.model.Vm</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/Vm/0004fb0000060000d0fadbda7b783b03</uri>
  #       <value>0004fb0000060000d0fadbda7b783b03</value>
  #     </vmIds>
  #     <vmIds>
  #       <name>sapvxp058</name>
  #       <type>com.oracle.ovm.mgr.ws.model.Vm</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/Vm/0004fb0000060000460ddbc31e0ed310</uri>
  #       <value>0004fb0000060000460ddbc31e0ed310</value>
  #     </vmIds>
  #     <vmIds>
  #       <name>sapvxp007</name>
  #       <type>com.oracle.ovm.mgr.ws.model.Vm</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/Vm/0004fb0000060000e8f10923be05c965</uri>
  #       <value>0004fb0000060000e8f10923be05c965</value>
  #     </vmIds>
  #     <vmIds>
  #       <name>sapvxp010</name>
  #       <type>com.oracle.ovm.mgr.ws.model.Vm</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/Vm/0004fb000006000096a96126e8d1fb64</uri>
  #       <value>0004fb000006000096a96126e8d1fb64</value>
  #     </vmIds>
  #     <vmIds>
  #       <name>sapvxp005</name>
  #       <type>com.oracle.ovm.mgr.ws.model.Vm</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/Vm/0004fb0000060000cdd9c5e7992e2ed1</uri>
  #       <value>0004fb0000060000cdd9c5e7992e2ed1</value>
  #     </vmIds>
  #     <vmIds>
  #       <name>sapvxp803</name>
  #       <type>com.oracle.ovm.mgr.ws.model.Vm</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/Vm/0004fb00000600002168841ef1df48d3</uri>
  #       <value>0004fb00000600002168841ef1df48d3</value>
  #     </vmIds>
  #     <vmIds>
  #       <name>sapvxp060</name>
  #       <type>com.oracle.ovm.mgr.ws.model.Vm</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/Vm/0004fb00000600001e29d167990abf32</uri>
  #       <value>0004fb00000600001e29d167990abf32</value>
  #     </vmIds>
  #     <vmIds>
  #       <name>sapvxp065</name>
  #       <type>com.oracle.ovm.mgr.ws.model.Vm</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/Vm/0004fb0000060000e523182a28be038f</uri>
  #       <value>0004fb0000060000e523182a28be038f</value>
  #     </vmIds>
  #   </server>
  #   <server>
  #     <generation>181</generation>
  #     <id>
  #       <name>el01-cn02.sede.corp.sanpaoloimi.com</name>
  #       <type>com.oracle.ovm.mgr.ws.model.Server</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/Server/e0:23:c2:40:00:10:ff:ff:ff:ff:ff:ff:ff:20:00:08</uri>
  #       <value>e0:23:c2:40:00:10:ff:ff:ff:ff:ff:ff:ff:20:00:08</value>
  #     </id>
  #     <locked>false</locked>
  #     <name>el01-cn02.sede.corp.sanpaoloimi.com</name>
  #     <abilityMap>
  #       <entry>
  #         <key>iSCSI</key>
  #         <value>true</value>
  #       </entry>
  #       <entry>
  #         <key>Fibre Channel</key>
  #         <value>true</value>
  #       </entry>
  #       <entry>
  #         <key>Memory Alignment</key>
  #         <value>1048576</value>
  #       </entry>
  #       <entry>
  #         <key>Bond Mode Active Backup</key>
  #         <value>true</value>
  #       </entry>
  #       <entry>
  #         <key>Bond Mode Adaptive Load Balancing</key>
  #         <value>true</value>
  #       </entry>
  #       <entry>
  #         <key>Clusters</key>
  #         <value>true</value>
  #       </entry>
  #       <entry>
  #         <key>High Availability</key>
  #         <value>true</value>
  #       </entry>
  #       <entry>
  #         <key>Power on WOL</key>
  #         <value>true</value>
  #       </entry>
  #       <entry>
  #         <key>Migration Setup</key>
  #         <value>false</value>
  #       </entry>
  #       <entry>
  #         <key>NFS</key>
  #         <value>true</value>
  #       </entry>
  #       <entry>
  #         <key>YUM update</key>
  #         <value>true</value>
  #       </entry>
  #       <entry>
  #         <key>VNC Console</key>
  #         <value>true</value>
  #       </entry>
  #       <entry>
  #         <key>Serial Console</key>
  #         <value>true</value>
  #       </entry>
  #       <entry>
  #         <key>MTU Configuration</key>
  #         <value>true</value>
  #       </entry>
  #       <entry>
  #         <key>VM Suspend</key>
  #         <value>true</value>
  #       </entry>
  #       <entry>
  #         <key>Per-VM CPU Over-subscription</key>
  #         <value>true</value>
  #       </entry>
  #       <entry>
  #         <key>Maximum number of VNICS for HVM</key>
  #         <value>8</value>
  #       </entry>
  #       <entry>
  #         <key>Local Storage Element</key>
  #         <value>true</value>
  #       </entry>
  #       <entry>
  #         <key>Bond Mode Link Aggregation</key>
  #         <value>true</value>
  #       </entry>
  #       <entry>
  #         <key>All-VM CPU Over-subscription</key>
  #         <value>true</value>
  #       </entry>
  #     </abilityMap>
  #     <agentLogin>oracle</agentLogin>
  #     <agentPort>8899</agentPort>
  #     <biosReleaseDate>06/19/2012</biosReleaseDate>
  #     <biosVendor>American Megatrends Inc.</biosVendor>
  #     <biosVersion>17021300</biosVersion>
  #     <clusterId>
  #       <type>com.oracle.ovm.mgr.ws.model.Cluster</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/Cluster/f9734a05404f4a13</uri>
  #       <value>f9734a05404f4a13</value>
  #     </clusterId>
  #     <controlDomains>
  #       <agentVersion>3.2.1-183</agentVersion>
  #       <cpuCount>32</cpuCount>
  #       <memory>7168</memory>
  #       <osKernelRelease>2.6.39-300.22.2.el5uek</osKernelRelease>
  #       <osKernelVersion>#1 SMP Fri Jan 4 12:40:29 PST 2013</osKernelVersion>
  #       <osMajorVersion>5</osMajorVersion>
  #       <osMinorVersion>7</osMinorVersion>
  #       <osName>Oracle VM Server</osName>
  #       <osType>Linux</osType>
  #       <ovmVersion>3.2.1-517</ovmVersion>
  #       <rpmVersion>3.2.1-183</rpmVersion>
  #     </controlDomains>
  #     <coresPerProcessorSocket>8</coresPerProcessorSocket>
  #     <cpuArchitectureType>X86_64</cpuArchitectureType>
  #     <cpuCompatibilityGroupId>
  #       <name>Default_Intel_Family:6_Model:45</name>
  #       <type>com.oracle.ovm.mgr.ws.model.CpuCompatibilityGroup</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/CpuCompatibilityGroup/Default_Intel_F6_M45</uri>
  #       <value>Default_Intel_F6_M45</value>
  #     </cpuCompatibilityGroupId>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>1</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>2</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>3</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>4</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>5</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>6</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>7</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>8</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>9</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>10</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>11</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>12</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>13</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>14</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>15</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>16</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>17</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>18</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>19</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>20</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>21</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>22</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>23</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>24</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>25</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>26</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>27</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>28</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>29</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>30</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>31</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>32</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <enabledProcessorCores>16</enabledProcessorCores>
  #     <ethernetPortIds>
  #       <name>bond0 on el01-cn02.sede.corp.sanpaoloimi.com</name>
  #       <type>com.oracle.ovm.mgr.ws.model.EthernetPort</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/EthernetPort/0004fb00002000009a0ccd018c8e39cd</uri>
  #       <value>0004fb00002000009a0ccd018c8e39cd</value>
  #     </ethernetPortIds>
  #     <ethernetPortIds>
  #       <name>bond1 on el01-cn02.sede.corp.sanpaoloimi.com</name>
  #       <type>com.oracle.ovm.mgr.ws.model.EthernetPort</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/EthernetPort/0004fb000020000036963b66e8f2ce84</uri>
  #       <value>0004fb000020000036963b66e8f2ce84</value>
  #     </ethernetPortIds>
  #     <ethernetPortIds>
  #       <name>bond2 on el01-cn02.sede.corp.sanpaoloimi.com</name>
  #       <type>com.oracle.ovm.mgr.ws.model.EthernetPort</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/EthernetPort/0004fb00002000000475ea6b5168fbd3</uri>
  #       <value>0004fb00002000000475ea6b5168fbd3</value>
  #     </ethernetPortIds>
  #     <ethernetPortIds>
  #       <name>bond3 on el01-cn02.sede.corp.sanpaoloimi.com</name>
  #       <type>com.oracle.ovm.mgr.ws.model.EthernetPort</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/EthernetPort/0004fb000020000024b7982cfa1a8a5b</uri>
  #       <value>0004fb000020000024b7982cfa1a8a5b</value>
  #     </ethernetPortIds>
  #     <ethernetPortIds>
  #       <name>bond7 on el01-cn02.sede.corp.sanpaoloimi.com</name>
  #       <type>com.oracle.ovm.mgr.ws.model.EthernetPort</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/EthernetPort/0004fb0000200000b21e0c2a94cc849b</uri>
  #       <value>0004fb0000200000b21e0c2a94cc849b</value>
  #     </ethernetPortIds>
  #     <ethernetPortIds>
  #       <name>bond8 on el01-cn02.sede.corp.sanpaoloimi.com</name>
  #       <type>com.oracle.ovm.mgr.ws.model.EthernetPort</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/EthernetPort/0004fb00002000003c2624b7d24cfb22</uri>
  #       <value>0004fb00002000003c2624b7d24cfb22</value>
  #     </ethernetPortIds>
  #     <ethernetPortIds>
  #       <name>bond9 on el01-cn02.sede.corp.sanpaoloimi.com</name>
  #       <type>com.oracle.ovm.mgr.ws.model.EthernetPort</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/EthernetPort/0004fb00002000009ce4c78efa636017</uri>
  #       <value>0004fb00002000009ce4c78efa636017</value>
  #     </ethernetPortIds>
  #     <ethernetPortIds>
  #       <name>eth0 on el01-cn02.sede.corp.sanpaoloimi.com</name>
  #       <type>com.oracle.ovm.mgr.ws.model.EthernetPort</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/EthernetPort/0004fb0000200000d3bac6c7aeebb8c9</uri>
  #       <value>0004fb0000200000d3bac6c7aeebb8c9</value>
  #     </ethernetPortIds>
  #     <ethernetPortIds>
  #       <name>eth1 on el01-cn02.sede.corp.sanpaoloimi.com</name>
  #       <type>com.oracle.ovm.mgr.ws.model.EthernetPort</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/EthernetPort/0004fb00002000004d0e6f686b72cdc8</uri>
  #       <value>0004fb00002000004d0e6f686b72cdc8</value>
  #     </ethernetPortIds>
  #     <ethernetPortIds>
  #       <name>eth2 on el01-cn02.sede.corp.sanpaoloimi.com</name>
  #       <type>com.oracle.ovm.mgr.ws.model.EthernetPort</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/EthernetPort/0004fb00002000004c21eea4be08061f</uri>
  #       <value>0004fb00002000004c21eea4be08061f</value>
  #     </ethernetPortIds>
  #     <ethernetPortIds>
  #       <name>eth3 on el01-cn02.sede.corp.sanpaoloimi.com</name>
  #       <type>com.oracle.ovm.mgr.ws.model.EthernetPort</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/EthernetPort/0004fb0000200000f243d1b43c7164ef</uri>
  #       <value>0004fb0000200000f243d1b43c7164ef</value>
  #     </ethernetPortIds>
  #     <fileServerPluginIds>
  #       <name>Oracle OCFS2 File system</name>
  #       <type>com.oracle.ovm.mgr.ws.model.FileServerPlugin</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/FileServerPlugin/oracle.ocfs2.OCFS2.OCFS2Plugin%20(0.1.0-38)</uri>
  #       <value>oracle.ocfs2.OCFS2.OCFS2Plugin (0.1.0-38)</value>
  #     </fileServerPluginIds>
  #     <fileServerPluginIds>
  #       <name>Oracle Generic Network File System</name>
  #       <type>com.oracle.ovm.mgr.ws.model.FileServerPlugin</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/FileServerPlugin/oracle.generic.NFSPlugin.GenericNFSPlugin%20(1.1.0)</uri>
  #       <value>oracle.generic.NFSPlugin.GenericNFSPlugin (1.1.0)</value>
  #     </fileServerPluginIds>
  #     <fileSystemMountIds>
  #       <name>el01-cn02.sede.corp.sanpaoloimi.com_/OVS/Repositories/0004fb00000300008c29cbcc1a7781c0</name>
  #       <type>com.oracle.ovm.mgr.ws.model.FileSystemMount</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/FileSystemMount/e0:23:c2:40:00:10:ff:ff:ff:ff:ff:ff:ff:20:00:08_mount_%2FOVS%2FRepositories%2F0004fb00000300008c29cbcc1a7781c0</uri>
  #       <value>e0:23:c2:40:00:10:ff:ff:ff:ff:ff:ff:ff:20:00:08_mount_/OVS/Repositories/0004fb00000300008c29cbcc1a7781c0</value>
  #     </fileSystemMountIds>
  #     <haltOnError>false</haltOnError>
  #     <hostname>el01-cn02.sede.corp.sanpaoloimi.com</hostname>
  #     <hypervisor>
  #       <capabilities>XEN_3_0_PVM_x86_64</capabilities>
  #       <capabilities>XEN_3_0_PVM_x86_32</capabilities>
  #       <capabilities>XEN_3_0_HVM_x86_32</capabilities>
  #       <capabilities>XEN_3_0_HVM_x86_32_PAE</capabilities>
  #       <capabilities>XEN_3_0_HVM_x86_64</capabilities>
  #       <type>XEN</type>
  #       <version>4.1.3OVM</version>
  #     </hypervisor>
  #     <localStorageArrayId>
  #       <name>Generic Local Storage Array @ el01-cn02.sede.corp.sanpaoloimi.com</name>
  #       <type>com.oracle.ovm.mgr.ws.model.StorageArray</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/StorageArray/0004fb000009000055ca7609f3752b63</uri>
  #       <value>0004fb000009000055ca7609f3752b63</value>
  #     </localStorageArrayId>
  #     <maintenanceMode>false</maintenanceMode>
  #     <managerUuid>0004fb000001000048baef3bcc606861</managerUuid>
  #     <manufacturer>Oracle Corporation</manufacturer>
  #     <memory>262133</memory>
  #     <noExecuteFlag>true</noExecuteFlag>
  #     <ntpServers>10.254.250.1</ntpServers>
  #     <ntpServers>10.254.250.4</ntpServers>
  #     <ntpServers>10.254.250.5</ntpServers>
  #     <ovmVersion>3.2.1-517</ovmVersion>
  #     <populatedProcessorSockets>2</populatedProcessorSockets>
  #     <processorSpeed>2893120.0</processorSpeed>
  #     <productName>SUN FIRE X4170 M3</productName>
  #     <productSerialNumber>1249FML0P6</productSerialNumber>
  #     <runVmsEnabled>true</runVmsEnabled>
  #     <serverPoolId>
  #       <name>el01Pool1</name>
  #       <type>com.oracle.ovm.mgr.ws.model.ServerPool</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/ServerPool/0004fb0000020000f9734a05404f4a13</uri>
  #       <value>0004fb0000020000f9734a05404f4a13</value>
  #     </serverPoolId>
  #     <serverRoles>UTILITY</serverRoles>
  #     <serverRoles>VM</serverRoles>
  #     <serverRunState>RUNNING</serverRunState>
  #     <statisticInterval>20</statisticInterval>
  #     <storageArrayPluginIds>
  #       <name>Oracle Generic SCSI Plugin</name>
  #       <type>com.oracle.ovm.mgr.ws.model.StorageArrayPlugin</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/StorageArrayPlugin/oracle.generic.SCSIPlugin.GenericPlugin%20(1.1.0)</uri>
  #       <value>oracle.generic.SCSIPlugin.GenericPlugin (1.1.0)</value>
  #     </storageArrayPluginIds>
  #     <storageArrayPluginIds>
  #       <name>Sun ZFS Storage Appliance iSCSI/FC1.0.2-58</name>
  #       <type>com.oracle.ovm.mgr.ws.model.StorageArrayPlugin</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/StorageArrayPlugin/oracle.s7k.SCSIPlugin.SCSIPlugin%20(1.0.2-58)</uri>
  #       <value>oracle.s7k.SCSIPlugin.SCSIPlugin (1.0.2-58)</value>
  #     </storageArrayPluginIds>
  #     <storageInitiatorIds>
  #       <type>com.oracle.ovm.mgr.ws.model.StorageInitiator</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/StorageInitiator/iqn.1988-12.com.oracle:9f76e107b19</uri>
  #       <value>iqn.1988-12.com.oracle:9f76e107b19</value>
  #     </storageInitiatorIds>
  #     <storageInitiatorIds>
  #       <type>com.oracle.ovm.mgr.ws.model.StorageInitiator</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/StorageInitiator/storage.LocalStorageInitiator%20in%20e0:23:c2:40:00:10:ff:ff:ff:ff:ff:ff:ff:20:00:08</uri>
  #       <value>storage.LocalStorageInitiator in e0:23:c2:40:00:10:ff:ff:ff:ff:ff:ff:ff:20:00:08</value>
  #     </storageInitiatorIds>
  #     <threadsPerCore>2</threadsPerCore>
  #     <totalProcessorCores>16</totalProcessorCores>
  #     <usableMemory>125530</usableMemory>
  #     <vmIds>
  #       <name>ExalogicControlOpsCenterPC2</name>
  #       <type>com.oracle.ovm.mgr.ws.model.Vm</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/Vm/0004fb00000600000f8a965768a385f9</uri>
  #       <value>0004fb00000600000f8a965768a385f9</value>
  #     </vmIds>
  #     <vmIds>
  #       <name>sapvxp071</name>
  #       <type>com.oracle.ovm.mgr.ws.model.Vm</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/Vm/0004fb00000600000790bbebed23d3e0</uri>
  #       <value>0004fb00000600000790bbebed23d3e0</value>
  #     </vmIds>
  #     <vmIds>
  #       <name>sapvxp014</name>
  #       <type>com.oracle.ovm.mgr.ws.model.Vm</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/Vm/0004fb000006000084fd698aeb7d4f08</uri>
  #       <value>0004fb000006000084fd698aeb7d4f08</value>
  #     </vmIds>
  #     <vmIds>
  #       <name>sapvxp017</name>
  #       <type>com.oracle.ovm.mgr.ws.model.Vm</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/Vm/0004fb00000600006c15335e8edaf34f</uri>
  #       <value>0004fb00000600006c15335e8edaf34f</value>
  #     </vmIds>
  #     <vmIds>
  #       <name>sapvxp024</name>
  #       <type>com.oracle.ovm.mgr.ws.model.Vm</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/Vm/0004fb00000600002b7e04af4c9adf38</uri>
  #       <value>0004fb00000600002b7e04af4c9adf38</value>
  #     </vmIds>
  #     <vmIds>
  #       <name>sapvxp027</name>
  #       <type>com.oracle.ovm.mgr.ws.model.Vm</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/Vm/0004fb0000060000b6bff43643f10c82</uri>
  #       <value>0004fb0000060000b6bff43643f10c82</value>
  #     </vmIds>
  #     <vmIds>
  #       <name>sapvxp031</name>
  #       <type>com.oracle.ovm.mgr.ws.model.Vm</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/Vm/0004fb00000600002fce5c412d34d209</uri>
  #       <value>0004fb00000600002fce5c412d34d209</value>
  #     </vmIds>
  #     <vmIds>
  #       <name>sapvxp035</name>
  #       <type>com.oracle.ovm.mgr.ws.model.Vm</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/Vm/0004fb0000060000d4b68a22cbd33429</uri>
  #       <value>0004fb0000060000d4b68a22cbd33429</value>
  #     </vmIds>
  #     <vmIds>
  #       <name>sapvxp020</name>
  #       <type>com.oracle.ovm.mgr.ws.model.Vm</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/Vm/0004fb00000600003f8e619f7593c4e5</uri>
  #       <value>0004fb00000600003f8e619f7593c4e5</value>
  #     </vmIds>
  #     <vmIds>
  #       <name>sapvxp047</name>
  #       <type>com.oracle.ovm.mgr.ws.model.Vm</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/Vm/0004fb000006000012aa9695b30ccccc</uri>
  #       <value>0004fb000006000012aa9695b30ccccc</value>
  #     </vmIds>
  #     <vmIds>
  #       <name>sapvxp051</name>
  #       <type>com.oracle.ovm.mgr.ws.model.Vm</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/Vm/0004fb000006000041cb461d077af6ab</uri>
  #       <value>0004fb000006000041cb461d077af6ab</value>
  #     </vmIds>
  #     <vmIds>
  #       <name>sapvxp055</name>
  #       <type>com.oracle.ovm.mgr.ws.model.Vm</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/Vm/0004fb00000600007345a609ef263d8f</uri>
  #       <value>0004fb00000600007345a609ef263d8f</value>
  #     </vmIds>
  #     <vmIds>
  #       <name>sapvxp039</name>
  #       <type>com.oracle.ovm.mgr.ws.model.Vm</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/Vm/0004fb0000060000c641ec6e07df106d</uri>
  #       <value>0004fb0000060000c641ec6e07df106d</value>
  #     </vmIds>
  #     <vmIds>
  #       <name>sapvxp043</name>
  #       <type>com.oracle.ovm.mgr.ws.model.Vm</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/Vm/0004fb000006000004398d02d0ce7353</uri>
  #       <value>0004fb000006000004398d02d0ce7353</value>
  #     </vmIds>
  #     <vmIds>
  #       <name>sapvxp006</name>
  #       <type>com.oracle.ovm.mgr.ws.model.Vm</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/Vm/0004fb0000060000c5647abde39d4c83</uri>
  #       <value>0004fb0000060000c5647abde39d4c83</value>
  #     </vmIds>
  #     <vmIds>
  #       <name>sapvxp009</name>
  #       <type>com.oracle.ovm.mgr.ws.model.Vm</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/Vm/0004fb0000060000ff13df5b1a6fdd71</uri>
  #       <value>0004fb0000060000ff13df5b1a6fdd71</value>
  #     </vmIds>
  #     <vmIds>
  #       <name>sapvxp801</name>
  #       <type>com.oracle.ovm.mgr.ws.model.Vm</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/Vm/0004fb0000060000f96133fa3ebe55eb</uri>
  #       <value>0004fb0000060000f96133fa3ebe55eb</value>
  #     </vmIds>
  #     <vmIds>
  #       <name>sapvxp063</name>
  #       <type>com.oracle.ovm.mgr.ws.model.Vm</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/Vm/0004fb0000060000c16688193117d8da</uri>
  #       <value>0004fb0000060000c16688193117d8da</value>
  #     </vmIds>
  #     <vmIds>
  #       <name>sapvxp062</name>
  #       <type>com.oracle.ovm.mgr.ws.model.Vm</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/Vm/0004fb00000600005bbbc6f2f140ce85</uri>
  #       <value>0004fb00000600005bbbc6f2f140ce85</value>
  #     </vmIds>
  #     <vmIds>
  #       <name>sapvxp067</name>
  #       <type>com.oracle.ovm.mgr.ws.model.Vm</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/Vm/0004fb00000600009eb3dfda40b363d1</uri>
  #       <value>0004fb00000600009eb3dfda40b363d1</value>
  #     </vmIds>
  #   </server>
  #   <server>
  #     <generation>118</generation>
  #     <id>
  #       <name>el01-cn01.sede.corp.sanpaoloimi.com</name>
  #       <type>com.oracle.ovm.mgr.ws.model.Server</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/Server/e0:23:ba:30:00:10:ff:ff:ff:ff:ff:ff:ff:20:00:08</uri>
  #       <value>e0:23:ba:30:00:10:ff:ff:ff:ff:ff:ff:ff:20:00:08</value>
  #     </id>
  #     <locked>false</locked>
  #     <name>el01-cn01.sede.corp.sanpaoloimi.com</name>
  #     <abilityMap>
  #       <entry>
  #         <key>iSCSI</key>
  #         <value>true</value>
  #       </entry>
  #       <entry>
  #         <key>Fibre Channel</key>
  #         <value>true</value>
  #       </entry>
  #       <entry>
  #         <key>Memory Alignment</key>
  #         <value>1048576</value>
  #       </entry>
  #       <entry>
  #         <key>Bond Mode Active Backup</key>
  #         <value>true</value>
  #       </entry>
  #       <entry>
  #         <key>Bond Mode Adaptive Load Balancing</key>
  #         <value>true</value>
  #       </entry>
  #       <entry>
  #         <key>Clusters</key>
  #         <value>true</value>
  #       </entry>
  #       <entry>
  #         <key>High Availability</key>
  #         <value>true</value>
  #       </entry>
  #       <entry>
  #         <key>Power on WOL</key>
  #         <value>true</value>
  #       </entry>
  #       <entry>
  #         <key>Migration Setup</key>
  #         <value>false</value>
  #       </entry>
  #       <entry>
  #         <key>NFS</key>
  #         <value>true</value>
  #       </entry>
  #       <entry>
  #         <key>YUM update</key>
  #         <value>true</value>
  #       </entry>
  #       <entry>
  #         <key>VNC Console</key>
  #         <value>true</value>
  #       </entry>
  #       <entry>
  #         <key>Serial Console</key>
  #         <value>true</value>
  #       </entry>
  #       <entry>
  #         <key>MTU Configuration</key>
  #         <value>true</value>
  #       </entry>
  #       <entry>
  #         <key>VM Suspend</key>
  #         <value>true</value>
  #       </entry>
  #       <entry>
  #         <key>Per-VM CPU Over-subscription</key>
  #         <value>true</value>
  #       </entry>
  #       <entry>
  #         <key>Maximum number of VNICS for HVM</key>
  #         <value>8</value>
  #       </entry>
  #       <entry>
  #         <key>Local Storage Element</key>
  #         <value>true</value>
  #       </entry>
  #       <entry>
  #         <key>Bond Mode Link Aggregation</key>
  #         <value>true</value>
  #       </entry>
  #       <entry>
  #         <key>All-VM CPU Over-subscription</key>
  #         <value>true</value>
  #       </entry>
  #     </abilityMap>
  #     <agentLogin>oracle</agentLogin>
  #     <agentPort>8899</agentPort>
  #     <biosReleaseDate>06/19/2012</biosReleaseDate>
  #     <biosVendor>American Megatrends Inc.</biosVendor>
  #     <biosVersion>17021300</biosVersion>
  #     <clusterId>
  #       <type>com.oracle.ovm.mgr.ws.model.Cluster</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/Cluster/f9734a05404f4a13</uri>
  #       <value>f9734a05404f4a13</value>
  #     </clusterId>
  #     <controlDomains>
  #       <agentVersion>3.2.1-183</agentVersion>
  #       <cpuCount>32</cpuCount>
  #       <memory>7168</memory>
  #       <osKernelRelease>2.6.39-300.22.2.el5uek</osKernelRelease>
  #       <osKernelVersion>#1 SMP Fri Jan 4 12:40:29 PST 2013</osKernelVersion>
  #       <osMajorVersion>5</osMajorVersion>
  #       <osMinorVersion>7</osMinorVersion>
  #       <osName>Oracle VM Server</osName>
  #       <osType>Linux</osType>
  #       <ovmVersion>3.2.1-517</ovmVersion>
  #       <rpmVersion>3.2.1-183</rpmVersion>
  #     </controlDomains>
  #     <coresPerProcessorSocket>8</coresPerProcessorSocket>
  #     <cpuArchitectureType>X86_64</cpuArchitectureType>
  #     <cpuCompatibilityGroupId>
  #       <name>Default_Intel_Family:6_Model:45</name>
  #       <type>com.oracle.ovm.mgr.ws.model.CpuCompatibilityGroup</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/CpuCompatibilityGroup/Default_Intel_F6_M45</uri>
  #       <value>Default_Intel_F6_M45</value>
  #     </cpuCompatibilityGroupId>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>1</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>2</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>3</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>4</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>5</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>6</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>7</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>8</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>9</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>10</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>11</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>12</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>13</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>14</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>15</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>16</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>17</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>18</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>19</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>20</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>21</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>22</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>23</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>24</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>25</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>26</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>27</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>28</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>29</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>30</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>31</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>32</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <enabledProcessorCores>16</enabledProcessorCores>
  #     <ethernetPortIds>
  #       <name>bond0 on el01-cn01.sede.corp.sanpaoloimi.com</name>
  #       <type>com.oracle.ovm.mgr.ws.model.EthernetPort</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/EthernetPort/0004fb0000200000325ab97e5aeec9b5</uri>
  #       <value>0004fb0000200000325ab97e5aeec9b5</value>
  #     </ethernetPortIds>
  #     <ethernetPortIds>
  #       <name>bond1 on el01-cn01.sede.corp.sanpaoloimi.com</name>
  #       <type>com.oracle.ovm.mgr.ws.model.EthernetPort</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/EthernetPort/0004fb0000200000ade6e283641411d6</uri>
  #       <value>0004fb0000200000ade6e283641411d6</value>
  #     </ethernetPortIds>
  #     <ethernetPortIds>
  #       <name>bond2 on el01-cn01.sede.corp.sanpaoloimi.com</name>
  #       <type>com.oracle.ovm.mgr.ws.model.EthernetPort</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/EthernetPort/0004fb0000200000b1f6ae003d562014</uri>
  #       <value>0004fb0000200000b1f6ae003d562014</value>
  #     </ethernetPortIds>
  #     <ethernetPortIds>
  #       <name>bond3 on el01-cn01.sede.corp.sanpaoloimi.com</name>
  #       <type>com.oracle.ovm.mgr.ws.model.EthernetPort</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/EthernetPort/0004fb000020000076bd01a7cd1375c8</uri>
  #       <value>0004fb000020000076bd01a7cd1375c8</value>
  #     </ethernetPortIds>
  #     <ethernetPortIds>
  #       <name>bond7 on el01-cn01.sede.corp.sanpaoloimi.com</name>
  #       <type>com.oracle.ovm.mgr.ws.model.EthernetPort</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/EthernetPort/0004fb00002000000eccf093d9a640a4</uri>
  #       <value>0004fb00002000000eccf093d9a640a4</value>
  #     </ethernetPortIds>
  #     <ethernetPortIds>
  #       <name>bond8 on el01-cn01.sede.corp.sanpaoloimi.com</name>
  #       <type>com.oracle.ovm.mgr.ws.model.EthernetPort</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/EthernetPort/0004fb000020000064c6d8483e221ae6</uri>
  #       <value>0004fb000020000064c6d8483e221ae6</value>
  #     </ethernetPortIds>
  #     <ethernetPortIds>
  #       <name>bond9 on el01-cn01.sede.corp.sanpaoloimi.com</name>
  #       <type>com.oracle.ovm.mgr.ws.model.EthernetPort</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/EthernetPort/0004fb000020000089e9f6a439331ec8</uri>
  #       <value>0004fb000020000089e9f6a439331ec8</value>
  #     </ethernetPortIds>
  #     <ethernetPortIds>
  #       <name>eth0 on el01-cn01.sede.corp.sanpaoloimi.com</name>
  #       <type>com.oracle.ovm.mgr.ws.model.EthernetPort</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/EthernetPort/0004fb0000200000114e1c85a87134d5</uri>
  #       <value>0004fb0000200000114e1c85a87134d5</value>
  #     </ethernetPortIds>
  #     <ethernetPortIds>
  #       <name>eth1 on el01-cn01.sede.corp.sanpaoloimi.com</name>
  #       <type>com.oracle.ovm.mgr.ws.model.EthernetPort</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/EthernetPort/0004fb000020000097ac8ab85335beee</uri>
  #       <value>0004fb000020000097ac8ab85335beee</value>
  #     </ethernetPortIds>
  #     <ethernetPortIds>
  #       <name>eth2 on el01-cn01.sede.corp.sanpaoloimi.com</name>
  #       <type>com.oracle.ovm.mgr.ws.model.EthernetPort</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/EthernetPort/0004fb00002000006583fa7e8d92efa7</uri>
  #       <value>0004fb00002000006583fa7e8d92efa7</value>
  #     </ethernetPortIds>
  #     <ethernetPortIds>
  #       <name>eth3 on el01-cn01.sede.corp.sanpaoloimi.com</name>
  #       <type>com.oracle.ovm.mgr.ws.model.EthernetPort</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/EthernetPort/0004fb00002000000d270ce43dd91071</uri>
  #       <value>0004fb00002000000d270ce43dd91071</value>
  #     </ethernetPortIds>
  #     <fileServerPluginIds>
  #       <name>Oracle OCFS2 File system</name>
  #       <type>com.oracle.ovm.mgr.ws.model.FileServerPlugin</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/FileServerPlugin/oracle.ocfs2.OCFS2.OCFS2Plugin%20(0.1.0-38)</uri>
  #       <value>oracle.ocfs2.OCFS2.OCFS2Plugin (0.1.0-38)</value>
  #     </fileServerPluginIds>
  #     <fileServerPluginIds>
  #       <name>Oracle Generic Network File System</name>
  #       <type>com.oracle.ovm.mgr.ws.model.FileServerPlugin</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/FileServerPlugin/oracle.generic.NFSPlugin.GenericNFSPlugin%20(1.1.0)</uri>
  #       <value>oracle.generic.NFSPlugin.GenericNFSPlugin (1.1.0)</value>
  #     </fileServerPluginIds>
  #     <fileSystemMountIds>
  #       <name>el01-cn01.sede.corp.sanpaoloimi.com_/nfsmnt/6e562645-0f3a-4f2c-885f-91fe857ef3d4</name>
  #       <type>com.oracle.ovm.mgr.ws.model.FileSystemMount</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/FileSystemMount/e0:23:ba:30:00:10:ff:ff:ff:ff:ff:ff:ff:20:00:08_mount_%2Fnfsmnt%2F6e562645-0f3a-4f2c-885f-91fe857ef3d4</uri>
  #       <value>e0:23:ba:30:00:10:ff:ff:ff:ff:ff:ff:ff:20:00:08_mount_/nfsmnt/6e562645-0f3a-4f2c-885f-91fe857ef3d4</value>
  #     </fileSystemMountIds>
  #     <fileSystemMountIds>
  #       <name>el01-cn01.sede.corp.sanpaoloimi.com_/OVS/Repositories/0004fb00000300008c29cbcc1a7781c0</name>
  #       <type>com.oracle.ovm.mgr.ws.model.FileSystemMount</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/FileSystemMount/e0:23:ba:30:00:10:ff:ff:ff:ff:ff:ff:ff:20:00:08_mount_%2FOVS%2FRepositories%2F0004fb00000300008c29cbcc1a7781c0</uri>
  #       <value>e0:23:ba:30:00:10:ff:ff:ff:ff:ff:ff:ff:20:00:08_mount_/OVS/Repositories/0004fb00000300008c29cbcc1a7781c0</value>
  #     </fileSystemMountIds>
  #     <fileSystemMountIds>
  #       <name>el01-cn01.sede.corp.sanpaoloimi.com_/mnt/ExalogicControl</name>
  #       <type>com.oracle.ovm.mgr.ws.model.FileSystemMount</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/FileSystemMount/e0:23:ba:30:00:10:ff:ff:ff:ff:ff:ff:ff:20:00:08_mount_%2Fmnt%2FExalogicControl</uri>
  #       <value>e0:23:ba:30:00:10:ff:ff:ff:ff:ff:ff:ff:20:00:08_mount_/mnt/ExalogicControl</value>
  #     </fileSystemMountIds>
  #     <haltOnError>false</haltOnError>
  #     <hostname>el01-cn01.sede.corp.sanpaoloimi.com</hostname>
  #     <hypervisor>
  #       <capabilities>XEN_3_0_PVM_x86_64</capabilities>
  #       <capabilities>XEN_3_0_PVM_x86_32</capabilities>
  #       <capabilities>XEN_3_0_HVM_x86_32</capabilities>
  #       <capabilities>XEN_3_0_HVM_x86_32_PAE</capabilities>
  #       <capabilities>XEN_3_0_HVM_x86_64</capabilities>
  #       <type>XEN</type>
  #       <version>4.1.3OVM</version>
  #     </hypervisor>
  #     <localStorageArrayId>
  #       <name>Generic Local Storage Array @ el01-cn01.sede.corp.sanpaoloimi.com</name>
  #       <type>com.oracle.ovm.mgr.ws.model.StorageArray</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/StorageArray/0004fb000009000076db5dacf12ac328</uri>
  #       <value>0004fb000009000076db5dacf12ac328</value>
  #     </localStorageArrayId>
  #     <maintenanceMode>false</maintenanceMode>
  #     <managerUuid>0004fb000001000048baef3bcc606861</managerUuid>
  #     <manufacturer>Oracle Corporation</manufacturer>
  #     <memory>262133</memory>
  #     <noExecuteFlag>true</noExecuteFlag>
  #     <ntpServers>10.254.250.1</ntpServers>
  #     <ntpServers>10.254.250.4</ntpServers>
  #     <ntpServers>10.254.250.5</ntpServers>
  #     <ovmVersion>3.2.1-517</ovmVersion>
  #     <populatedProcessorSockets>2</populatedProcessorSockets>
  #     <processorSpeed>2893143.0</processorSpeed>
  #     <productName>SUN FIRE X4170 M3</productName>
  #     <productSerialNumber>1250FML012</productSerialNumber>
  #     <refreshFileServerIds>
  #       <name>Generic Network File System</name>
  #       <type>com.oracle.ovm.mgr.ws.model.FileServer</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/FileServer/0004fb0000090000573914ba832685d5</uri>
  #       <value>0004fb0000090000573914ba832685d5</value>
  #     </refreshFileServerIds>
  #     <runVmsEnabled>true</runVmsEnabled>
  #     <serverPoolId>
  #       <name>el01Pool1</name>
  #       <type>com.oracle.ovm.mgr.ws.model.ServerPool</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/ServerPool/0004fb0000020000f9734a05404f4a13</uri>
  #       <value>0004fb0000020000f9734a05404f4a13</value>
  #     </serverPoolId>
  #     <serverRoles>VM</serverRoles>
  #     <serverRoles>UTILITY</serverRoles>
  #     <serverRunState>RUNNING</serverRunState>
  #     <statisticInterval>20</statisticInterval>
  #     <storageArrayPluginIds>
  #       <name>Sun ZFS Storage Appliance iSCSI/FC1.0.2-58</name>
  #       <type>com.oracle.ovm.mgr.ws.model.StorageArrayPlugin</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/StorageArrayPlugin/oracle.s7k.SCSIPlugin.SCSIPlugin%20(1.0.2-58)</uri>
  #       <value>oracle.s7k.SCSIPlugin.SCSIPlugin (1.0.2-58)</value>
  #     </storageArrayPluginIds>
  #     <storageArrayPluginIds>
  #       <name>Oracle Generic SCSI Plugin</name>
  #       <type>com.oracle.ovm.mgr.ws.model.StorageArrayPlugin</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/StorageArrayPlugin/oracle.generic.SCSIPlugin.GenericPlugin%20(1.1.0)</uri>
  #       <value>oracle.generic.SCSIPlugin.GenericPlugin (1.1.0)</value>
  #     </storageArrayPluginIds>
  #     <storageInitiatorIds>
  #       <type>com.oracle.ovm.mgr.ws.model.StorageInitiator</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/StorageInitiator/iqn.1988-12.com.oracle:266dd9aedfaf</uri>
  #       <value>iqn.1988-12.com.oracle:266dd9aedfaf</value>
  #     </storageInitiatorIds>
  #     <storageInitiatorIds>
  #       <type>com.oracle.ovm.mgr.ws.model.StorageInitiator</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/StorageInitiator/storage.LocalStorageInitiator%20in%20e0:23:ba:30:00:10:ff:ff:ff:ff:ff:ff:ff:20:00:08</uri>
  #       <value>storage.LocalStorageInitiator in e0:23:ba:30:00:10:ff:ff:ff:ff:ff:ff:ff:20:00:08</value>
  #     </storageInitiatorIds>
  #     <threadsPerCore>2</threadsPerCore>
  #     <totalProcessorCores>16</totalProcessorCores>
  #     <usableMemory>154379</usableMemory>
  #     <vmIds>
  #       <name>ExalogicControl</name>
  #       <type>com.oracle.ovm.mgr.ws.model.Vm</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/Vm/0004fb00000600002f88faa8d6f43f44</uri>
  #       <value>0004fb00000600002f88faa8d6f43f44</value>
  #     </vmIds>
  #     <vmIds>
  #       <name>ExalogicControlOpsCenterPC1</name>
  #       <type>com.oracle.ovm.mgr.ws.model.Vm</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/Vm/0004fb0000060000b574adfff34a6c35</uri>
  #       <value>0004fb0000060000b574adfff34a6c35</value>
  #     </vmIds>
  #     <vmIds>
  #       <name>sapvxp021</name>
  #       <type>com.oracle.ovm.mgr.ws.model.Vm</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/Vm/0004fb0000060000433c2e6fd33c5592</uri>
  #       <value>0004fb0000060000433c2e6fd33c5592</value>
  #     </vmIds>
  #     <vmIds>
  #       <name>sapvxp025</name>
  #       <type>com.oracle.ovm.mgr.ws.model.Vm</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/Vm/0004fb0000060000a8a7c3d6caa35cc0</uri>
  #       <value>0004fb0000060000a8a7c3d6caa35cc0</value>
  #     </vmIds>
  #     <vmIds>
  #       <name>sapvxp029</name>
  #       <type>com.oracle.ovm.mgr.ws.model.Vm</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/Vm/0004fb0000060000333c35b688266232</uri>
  #       <value>0004fb0000060000333c35b688266232</value>
  #     </vmIds>
  #     <vmIds>
  #       <name>sapvxp033</name>
  #       <type>com.oracle.ovm.mgr.ws.model.Vm</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/Vm/0004fb00000600009a0d3b4db9dc50aa</uri>
  #       <value>0004fb00000600009a0d3b4db9dc50aa</value>
  #     </vmIds>
  #     <vmIds>
  #       <name>sapvxp045</name>
  #       <type>com.oracle.ovm.mgr.ws.model.Vm</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/Vm/0004fb0000060000caa47abeea6faf60</uri>
  #       <value>0004fb0000060000caa47abeea6faf60</value>
  #     </vmIds>
  #     <vmIds>
  #       <name>sapvxp049</name>
  #       <type>com.oracle.ovm.mgr.ws.model.Vm</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/Vm/0004fb0000060000a50245338a6f23ba</uri>
  #       <value>0004fb0000060000a50245338a6f23ba</value>
  #     </vmIds>
  #     <vmIds>
  #       <name>sapvxp053</name>
  #       <type>com.oracle.ovm.mgr.ws.model.Vm</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/Vm/0004fb0000060000d51b329f5e49e0fe</uri>
  #       <value>0004fb0000060000d51b329f5e49e0fe</value>
  #     </vmIds>
  #     <vmIds>
  #       <name>sapvxp037</name>
  #       <type>com.oracle.ovm.mgr.ws.model.Vm</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/Vm/0004fb00000600001b2051b61eec286a</uri>
  #       <value>0004fb00000600001b2051b61eec286a</value>
  #     </vmIds>
  #     <vmIds>
  #       <name>sapvxp041</name>
  #       <type>com.oracle.ovm.mgr.ws.model.Vm</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/Vm/0004fb000006000061d398b345403607</uri>
  #       <value>0004fb000006000061d398b345403607</value>
  #     </vmIds>
  #     <vmIds>
  #       <name>sapvxp057</name>
  #       <type>com.oracle.ovm.mgr.ws.model.Vm</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/Vm/0004fb000006000047382b7e99919369</uri>
  #       <value>0004fb000006000047382b7e99919369</value>
  #     </vmIds>
  #     <vmIds>
  #       <name>sapvxp802</name>
  #       <type>com.oracle.ovm.mgr.ws.model.Vm</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/Vm/0004fb00000600008ec66e96a9b6899d</uri>
  #       <value>0004fb00000600008ec66e96a9b6899d</value>
  #     </vmIds>
  #     <vmIds>
  #       <name>sapvxp059</name>
  #       <type>com.oracle.ovm.mgr.ws.model.Vm</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/Vm/0004fb000006000024af99e0a1008db0</uri>
  #       <value>0004fb000006000024af99e0a1008db0</value>
  #     </vmIds>
  #     <vmIds>
  #       <name>sapvxp064</name>
  #       <type>com.oracle.ovm.mgr.ws.model.Vm</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/Vm/0004fb0000060000cc8eb29158597180</uri>
  #       <value>0004fb0000060000cc8eb29158597180</value>
  #     </vmIds>
  #     <vmIds>
  #       <name>sapvxp066</name>
  #       <type>com.oracle.ovm.mgr.ws.model.Vm</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/Vm/0004fb00000600005144788f86357148</uri>
  #       <value>0004fb00000600005144788f86357148</value>
  #     </vmIds>
  #   </server>
  #   <server>
  #     <generation>135</generation>
  #     <id>
  #       <name>el01-cn03.sede.corp.sanpaoloimi.com</name>
  #       <type>com.oracle.ovm.mgr.ws.model.Server</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/Server/e0:23:e8:fe:00:10:ff:ff:ff:ff:ff:ff:ff:20:00:08</uri>
  #       <value>e0:23:e8:fe:00:10:ff:ff:ff:ff:ff:ff:ff:20:00:08</value>
  #     </id>
  #     <locked>false</locked>
  #     <name>el01-cn03.sede.corp.sanpaoloimi.com</name>
  #     <abilityMap>
  #       <entry>
  #         <key>iSCSI</key>
  #         <value>true</value>
  #       </entry>
  #       <entry>
  #         <key>Fibre Channel</key>
  #         <value>true</value>
  #       </entry>
  #       <entry>
  #         <key>Memory Alignment</key>
  #         <value>1048576</value>
  #       </entry>
  #       <entry>
  #         <key>Bond Mode Active Backup</key>
  #         <value>true</value>
  #       </entry>
  #       <entry>
  #         <key>Bond Mode Adaptive Load Balancing</key>
  #         <value>true</value>
  #       </entry>
  #       <entry>
  #         <key>Clusters</key>
  #         <value>true</value>
  #       </entry>
  #       <entry>
  #         <key>High Availability</key>
  #         <value>true</value>
  #       </entry>
  #       <entry>
  #         <key>Power on WOL</key>
  #         <value>true</value>
  #       </entry>
  #       <entry>
  #         <key>Migration Setup</key>
  #         <value>false</value>
  #       </entry>
  #       <entry>
  #         <key>NFS</key>
  #         <value>true</value>
  #       </entry>
  #       <entry>
  #         <key>YUM update</key>
  #         <value>true</value>
  #       </entry>
  #       <entry>
  #         <key>VNC Console</key>
  #         <value>true</value>
  #       </entry>
  #       <entry>
  #         <key>Serial Console</key>
  #         <value>true</value>
  #       </entry>
  #       <entry>
  #         <key>MTU Configuration</key>
  #         <value>true</value>
  #       </entry>
  #       <entry>
  #         <key>VM Suspend</key>
  #         <value>true</value>
  #       </entry>
  #       <entry>
  #         <key>Per-VM CPU Over-subscription</key>
  #         <value>true</value>
  #       </entry>
  #       <entry>
  #         <key>Maximum number of VNICS for HVM</key>
  #         <value>8</value>
  #       </entry>
  #       <entry>
  #         <key>Local Storage Element</key>
  #         <value>true</value>
  #       </entry>
  #       <entry>
  #         <key>Bond Mode Link Aggregation</key>
  #         <value>true</value>
  #       </entry>
  #       <entry>
  #         <key>All-VM CPU Over-subscription</key>
  #         <value>true</value>
  #       </entry>
  #     </abilityMap>
  #     <agentLogin>oracle</agentLogin>
  #     <agentPort>8899</agentPort>
  #     <biosReleaseDate>06/19/2012</biosReleaseDate>
  #     <biosVendor>American Megatrends Inc.</biosVendor>
  #     <biosVersion>17021300</biosVersion>
  #     <clusterId>
  #       <type>com.oracle.ovm.mgr.ws.model.Cluster</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/Cluster/f9734a05404f4a13</uri>
  #       <value>f9734a05404f4a13</value>
  #     </clusterId>
  #     <controlDomains>
  #       <agentVersion>3.2.1-183</agentVersion>
  #       <cpuCount>32</cpuCount>
  #       <memory>7168</memory>
  #       <osKernelRelease>2.6.39-300.22.2.el5uek</osKernelRelease>
  #       <osKernelVersion>#1 SMP Fri Jan 4 12:40:29 PST 2013</osKernelVersion>
  #       <osMajorVersion>5</osMajorVersion>
  #       <osMinorVersion>7</osMinorVersion>
  #       <osName>Oracle VM Server</osName>
  #       <osType>Linux</osType>
  #       <ovmVersion>3.2.1-517</ovmVersion>
  #       <rpmVersion>3.2.1-183</rpmVersion>
  #     </controlDomains>
  #     <coresPerProcessorSocket>8</coresPerProcessorSocket>
  #     <cpuArchitectureType>X86_64</cpuArchitectureType>
  #     <cpuCompatibilityGroupId>
  #       <name>Default_Intel_Family:6_Model:45</name>
  #       <type>com.oracle.ovm.mgr.ws.model.CpuCompatibilityGroup</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/CpuCompatibilityGroup/Default_Intel_F6_M45</uri>
  #       <value>Default_Intel_F6_M45</value>
  #     </cpuCompatibilityGroupId>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>1</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>2</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>3</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>4</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>5</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>6</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>7</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>8</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>9</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>10</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>11</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>12</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>13</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>14</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>15</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>16</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>17</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>18</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>19</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>20</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>21</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>22</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>23</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>24</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>25</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>26</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>27</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>28</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>29</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>30</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>31</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <cpus>
  #       <cpuFamily>6</cpuFamily>
  #       <cpuModel>45</cpuModel>
  #       <cpuNumber>32</cpuNumber>
  #       <family>GenuineIntel</family>
  #       <flags>fpu de tsc msr pae mce cx8 apic sep mca cmov pat clflush acpi mmx fxsr sse sse2 ss ht syscall nx lm constant_tsc rep_good nopl nonstop_tsc pni pclmulqdq est ssse3 cx16 sse4_1 sse4_2 x2apic popcnt aes hypervisor lahf_lm ida arat epb pln pts dts</flags>
  #       <levelOneCacheSize>0</levelOneCacheSize>
  #       <levelThreeCacheSize>0</levelThreeCacheSize>
  #       <levelTwoCacheSize>20480</levelTwoCacheSize>
  #       <manufacturer>GenuineIntel</manufacturer>
  #       <modelName>Intel(R) Xeon(R) CPU E5-2690 0 @ 2.90GHz</modelName>
  #       <vendorId>GenuineIntel</vendorId>
  #       <virtualCpuNumber>-1</virtualCpuNumber>
  #     </cpus>
  #     <enabledProcessorCores>16</enabledProcessorCores>
  #     <ethernetPortIds>
  #       <name>bond0 on el01-cn03.sede.corp.sanpaoloimi.com</name>
  #       <type>com.oracle.ovm.mgr.ws.model.EthernetPort</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/EthernetPort/0004fb000020000052305f515c954e2c</uri>
  #       <value>0004fb000020000052305f515c954e2c</value>
  #     </ethernetPortIds>
  #     <ethernetPortIds>
  #       <name>bond1 on el01-cn03.sede.corp.sanpaoloimi.com</name>
  #       <type>com.oracle.ovm.mgr.ws.model.EthernetPort</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/EthernetPort/0004fb000020000017b3401f73222a10</uri>
  #       <value>0004fb000020000017b3401f73222a10</value>
  #     </ethernetPortIds>
  #     <ethernetPortIds>
  #       <name>bond2 on el01-cn03.sede.corp.sanpaoloimi.com</name>
  #       <type>com.oracle.ovm.mgr.ws.model.EthernetPort</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/EthernetPort/0004fb000020000069e796aa74b97f89</uri>
  #       <value>0004fb000020000069e796aa74b97f89</value>
  #     </ethernetPortIds>
  #     <ethernetPortIds>
  #       <name>bond3 on el01-cn03.sede.corp.sanpaoloimi.com</name>
  #       <type>com.oracle.ovm.mgr.ws.model.EthernetPort</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/EthernetPort/0004fb0000200000aae2cd4488c3ac72</uri>
  #       <value>0004fb0000200000aae2cd4488c3ac72</value>
  #     </ethernetPortIds>
  #     <ethernetPortIds>
  #       <name>bond7 on el01-cn03.sede.corp.sanpaoloimi.com</name>
  #       <type>com.oracle.ovm.mgr.ws.model.EthernetPort</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/EthernetPort/0004fb00002000004523d3fedf72467d</uri>
  #       <value>0004fb00002000004523d3fedf72467d</value>
  #     </ethernetPortIds>
  #     <ethernetPortIds>
  #       <name>bond8 on el01-cn03.sede.corp.sanpaoloimi.com</name>
  #       <type>com.oracle.ovm.mgr.ws.model.EthernetPort</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/EthernetPort/0004fb00002000003e8f7ce43b4cdee8</uri>
  #       <value>0004fb00002000003e8f7ce43b4cdee8</value>
  #     </ethernetPortIds>
  #     <ethernetPortIds>
  #       <name>bond9 on el01-cn03.sede.corp.sanpaoloimi.com</name>
  #       <type>com.oracle.ovm.mgr.ws.model.EthernetPort</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/EthernetPort/0004fb0000200000495cc89b1b5a6d68</uri>
  #       <value>0004fb0000200000495cc89b1b5a6d68</value>
  #     </ethernetPortIds>
  #     <ethernetPortIds>
  #       <name>eth0 on el01-cn03.sede.corp.sanpaoloimi.com</name>
  #       <type>com.oracle.ovm.mgr.ws.model.EthernetPort</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/EthernetPort/0004fb0000200000e0f5c1bd5c0c9d32</uri>
  #       <value>0004fb0000200000e0f5c1bd5c0c9d32</value>
  #     </ethernetPortIds>
  #     <ethernetPortIds>
  #       <name>eth1 on el01-cn03.sede.corp.sanpaoloimi.com</name>
  #       <type>com.oracle.ovm.mgr.ws.model.EthernetPort</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/EthernetPort/0004fb00002000000ca10224c73076cd</uri>
  #       <value>0004fb00002000000ca10224c73076cd</value>
  #     </ethernetPortIds>
  #     <ethernetPortIds>
  #       <name>eth2 on el01-cn03.sede.corp.sanpaoloimi.com</name>
  #       <type>com.oracle.ovm.mgr.ws.model.EthernetPort</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/EthernetPort/0004fb00002000003cc4ec643aaef659</uri>
  #       <value>0004fb00002000003cc4ec643aaef659</value>
  #     </ethernetPortIds>
  #     <ethernetPortIds>
  #       <name>eth3 on el01-cn03.sede.corp.sanpaoloimi.com</name>
  #       <type>com.oracle.ovm.mgr.ws.model.EthernetPort</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/EthernetPort/0004fb000020000025708e7be55232b9</uri>
  #       <value>0004fb000020000025708e7be55232b9</value>
  #     </ethernetPortIds>
  #     <fileServerPluginIds>
  #       <name>Oracle Generic Network File System</name>
  #       <type>com.oracle.ovm.mgr.ws.model.FileServerPlugin</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/FileServerPlugin/oracle.generic.NFSPlugin.GenericNFSPlugin%20(1.1.0)</uri>
  #       <value>oracle.generic.NFSPlugin.GenericNFSPlugin (1.1.0)</value>
  #     </fileServerPluginIds>
  #     <fileServerPluginIds>
  #       <name>Oracle OCFS2 File system</name>
  #       <type>com.oracle.ovm.mgr.ws.model.FileServerPlugin</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/FileServerPlugin/oracle.ocfs2.OCFS2.OCFS2Plugin%20(0.1.0-38)</uri>
  #       <value>oracle.ocfs2.OCFS2.OCFS2Plugin (0.1.0-38)</value>
  #     </fileServerPluginIds>
  #     <fileSystemMountIds>
  #       <name>el01-cn03.sede.corp.sanpaoloimi.com_/OVS/Repositories/0004fb00000300008c29cbcc1a7781c0</name>
  #       <type>com.oracle.ovm.mgr.ws.model.FileSystemMount</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/FileSystemMount/e0:23:e8:fe:00:10:ff:ff:ff:ff:ff:ff:ff:20:00:08_mount_%2FOVS%2FRepositories%2F0004fb00000300008c29cbcc1a7781c0</uri>
  #       <value>e0:23:e8:fe:00:10:ff:ff:ff:ff:ff:ff:ff:20:00:08_mount_/OVS/Repositories/0004fb00000300008c29cbcc1a7781c0</value>
  #     </fileSystemMountIds>
  #     <haltOnError>false</haltOnError>
  #     <hostname>el01-cn03.sede.corp.sanpaoloimi.com</hostname>
  #     <hypervisor>
  #       <capabilities>XEN_3_0_PVM_x86_64</capabilities>
  #       <capabilities>XEN_3_0_PVM_x86_32</capabilities>
  #       <capabilities>XEN_3_0_HVM_x86_32</capabilities>
  #       <capabilities>XEN_3_0_HVM_x86_32_PAE</capabilities>
  #       <capabilities>XEN_3_0_HVM_x86_64</capabilities>
  #       <type>XEN</type>
  #       <version>4.1.3OVM</version>
  #     </hypervisor>
  #     <localStorageArrayId>
  #       <name>Generic Local Storage Array @ el01-cn03.sede.corp.sanpaoloimi.com</name>
  #       <type>com.oracle.ovm.mgr.ws.model.StorageArray</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/StorageArray/0004fb00000900001f99e2a9a0d118da</uri>
  #       <value>0004fb00000900001f99e2a9a0d118da</value>
  #     </localStorageArrayId>
  #     <maintenanceMode>false</maintenanceMode>
  #     <managerUuid>0004fb000001000048baef3bcc606861</managerUuid>
  #     <manufacturer>Oracle Corporation</manufacturer>
  #     <memory>262133</memory>
  #     <noExecuteFlag>true</noExecuteFlag>
  #     <ntpServers>10.254.250.1</ntpServers>
  #     <ntpServers>10.254.250.4</ntpServers>
  #     <ntpServers>10.254.250.5</ntpServers>
  #     <ovmVersion>3.2.1-517</ovmVersion>
  #     <populatedProcessorSockets>2</populatedProcessorSockets>
  #     <processorSpeed>2893095.0</processorSpeed>
  #     <productName>SUN FIRE X4170 M3</productName>
  #     <productSerialNumber>1250FML01K</productSerialNumber>
  #     <runVmsEnabled>true</runVmsEnabled>
  #     <serverPoolId>
  #       <name>el01Pool1</name>
  #       <type>com.oracle.ovm.mgr.ws.model.ServerPool</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/ServerPool/0004fb0000020000f9734a05404f4a13</uri>
  #       <value>0004fb0000020000f9734a05404f4a13</value>
  #     </serverPoolId>
  #     <serverRoles>UTILITY</serverRoles>
  #     <serverRoles>VM</serverRoles>
  #     <serverRunState>RUNNING</serverRunState>
  #     <statisticInterval>20</statisticInterval>
  #     <storageArrayPluginIds>
  #       <name>Sun ZFS Storage Appliance iSCSI/FC1.0.2-58</name>
  #       <type>com.oracle.ovm.mgr.ws.model.StorageArrayPlugin</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/StorageArrayPlugin/oracle.s7k.SCSIPlugin.SCSIPlugin%20(1.0.2-58)</uri>
  #       <value>oracle.s7k.SCSIPlugin.SCSIPlugin (1.0.2-58)</value>
  #     </storageArrayPluginIds>
  #     <storageArrayPluginIds>
  #       <name>Oracle Generic SCSI Plugin</name>
  #       <type>com.oracle.ovm.mgr.ws.model.StorageArrayPlugin</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/StorageArrayPlugin/oracle.generic.SCSIPlugin.GenericPlugin%20(1.1.0)</uri>
  #       <value>oracle.generic.SCSIPlugin.GenericPlugin (1.1.0)</value>
  #     </storageArrayPluginIds>
  #     <storageInitiatorIds>
  #       <type>com.oracle.ovm.mgr.ws.model.StorageInitiator</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/StorageInitiator/iqn.1988-12.com.oracle:9bca9224ca0</uri>
  #       <value>iqn.1988-12.com.oracle:9bca9224ca0</value>
  #     </storageInitiatorIds>
  #     <storageInitiatorIds>
  #       <type>com.oracle.ovm.mgr.ws.model.StorageInitiator</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/StorageInitiator/storage.LocalStorageInitiator%20in%20e0:23:e8:fe:00:10:ff:ff:ff:ff:ff:ff:ff:20:00:08</uri>
  #       <value>storage.LocalStorageInitiator in e0:23:e8:fe:00:10:ff:ff:ff:ff:ff:ff:ff:20:00:08</value>
  #     </storageInitiatorIds>
  #     <threadsPerCore>2</threadsPerCore>
  #     <totalProcessorCores>16</totalProcessorCores>
  #     <usableMemory>130650</usableMemory>
  #     <vmIds>
  #       <name>sapvxp072</name>
  #       <type>com.oracle.ovm.mgr.ws.model.Vm</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/Vm/0004fb0000060000b60e9f4913c1b7a9</uri>
  #       <value>0004fb0000060000b60e9f4913c1b7a9</value>
  #     </vmIds>
  #     <vmIds>
  #       <name>sgevxp001</name>
  #       <type>com.oracle.ovm.mgr.ws.model.Vm</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/Vm/0004fb00000600000a6d223794fb1f9c</uri>
  #       <value>0004fb00000600000a6d223794fb1f9c</value>
  #     </vmIds>
  #     <vmIds>
  #       <name>sapvxp016</name>
  #       <type>com.oracle.ovm.mgr.ws.model.Vm</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/Vm/0004fb0000060000fbfe54b35b755c5d</uri>
  #       <value>0004fb0000060000fbfe54b35b755c5d</value>
  #     </vmIds>
  #     <vmIds>
  #       <name>sapvxp019</name>
  #       <type>com.oracle.ovm.mgr.ws.model.Vm</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/Vm/0004fb000006000028a7f704a2e1aac8</uri>
  #       <value>0004fb000006000028a7f704a2e1aac8</value>
  #     </vmIds>
  #     <vmIds>
  #       <name>sapvxp023</name>
  #       <type>com.oracle.ovm.mgr.ws.model.Vm</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/Vm/0004fb000006000038cd15da80dccba8</uri>
  #       <value>0004fb000006000038cd15da80dccba8</value>
  #     </vmIds>
  #     <vmIds>
  #       <name>sgevxp002</name>
  #       <type>com.oracle.ovm.mgr.ws.model.Vm</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/Vm/0004fb00000600009450eaa036100a1c</uri>
  #       <value>0004fb00000600009450eaa036100a1c</value>
  #     </vmIds>
  #     <vmIds>
  #       <name>sapvxp012</name>
  #       <type>com.oracle.ovm.mgr.ws.model.Vm</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/Vm/0004fb00000600003060e2b17bd57a67</uri>
  #       <value>0004fb00000600003060e2b17bd57a67</value>
  #     </vmIds>
  #     <vmIds>
  #       <name>sapvxp028</name>
  #       <type>com.oracle.ovm.mgr.ws.model.Vm</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/Vm/0004fb000006000055de4c9df64e2619</uri>
  #       <value>0004fb000006000055de4c9df64e2619</value>
  #     </vmIds>
  #     <vmIds>
  #       <name>sapvxp032</name>
  #       <type>com.oracle.ovm.mgr.ws.model.Vm</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/Vm/0004fb0000060000d9bc99fce21919dd</uri>
  #       <value>0004fb0000060000d9bc99fce21919dd</value>
  #     </vmIds>
  #     <vmIds>
  #       <name>sapvxp036</name>
  #       <type>com.oracle.ovm.mgr.ws.model.Vm</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/Vm/0004fb00000600001cdd4cca37e932df</uri>
  #       <value>0004fb00000600001cdd4cca37e932df</value>
  #     </vmIds>
  #     <vmIds>
  #       <name>sapvxp048</name>
  #       <type>com.oracle.ovm.mgr.ws.model.Vm</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/Vm/0004fb00000600007425631383362204</uri>
  #       <value>0004fb00000600007425631383362204</value>
  #     </vmIds>
  #     <vmIds>
  #       <name>sapvxp052</name>
  #       <type>com.oracle.ovm.mgr.ws.model.Vm</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/Vm/0004fb000006000016e37c2f8c53b938</uri>
  #       <value>0004fb000006000016e37c2f8c53b938</value>
  #     </vmIds>
  #     <vmIds>
  #       <name>sapvxp056</name>
  #       <type>com.oracle.ovm.mgr.ws.model.Vm</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/Vm/0004fb000006000043968202931d1074</uri>
  #       <value>0004fb000006000043968202931d1074</value>
  #     </vmIds>
  #     <vmIds>
  #       <name>sapvxp040</name>
  #       <type>com.oracle.ovm.mgr.ws.model.Vm</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/Vm/0004fb0000060000de6917589d5fb0f2</uri>
  #       <value>0004fb0000060000de6917589d5fb0f2</value>
  #     </vmIds>
  #     <vmIds>
  #       <name>sapvxp044</name>
  #       <type>com.oracle.ovm.mgr.ws.model.Vm</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/Vm/0004fb00000600000768a77da40e170e</uri>
  #       <value>0004fb00000600000768a77da40e170e</value>
  #     </vmIds>
  #     <vmIds>
  #       <name>sapvxp008</name>
  #       <type>com.oracle.ovm.mgr.ws.model.Vm</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/Vm/0004fb0000060000ee55d2398303e9b3</uri>
  #       <value>0004fb0000060000ee55d2398303e9b3</value>
  #     </vmIds>
  #     <vmIds>
  #       <name>sapvxp011</name>
  #       <type>com.oracle.ovm.mgr.ws.model.Vm</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/Vm/0004fb0000060000077912a43a9033c2</uri>
  #       <value>0004fb0000060000077912a43a9033c2</value>
  #     </vmIds>
  #     <vmIds>
  #       <name>sapvxp804</name>
  #       <type>com.oracle.ovm.mgr.ws.model.Vm</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/Vm/0004fb0000060000012b342d16c90945</uri>
  #       <value>0004fb0000060000012b342d16c90945</value>
  #     </vmIds>
  #     <vmIds>
  #       <name>sapvxp061</name>
  #       <type>com.oracle.ovm.mgr.ws.model.Vm</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/Vm/0004fb00000600000b8fe4d8a17c3488</uri>
  #       <value>0004fb00000600000b8fe4d8a17c3488</value>
  #     </vmIds>
  #     <vmIds>
  #       <name>sapvxp900</name>
  #       <type>com.oracle.ovm.mgr.ws.model.Vm</type>
  #       <uri>https://10.248.192.176:7002/ovm/core/wsapi/rest/Vm/0004fb0000060000c274e0ca007c0427</uri>
  #       <value>0004fb0000060000c274e0ca007c0427</value>
  #     </vmIds>
  #   </server>
  # </servers>

  my $ovmm_ua = Mojo::UserAgent->new;

  # lookup vdc config (username, password, endpoint) in mongodb
  my $vdcs_collection=$db->get_collection('vdcs');
  my $find_result=$vdcs_collection->find({"display_name" => $vdc});
  my @vdcs=$find_result->all;

  if (@vdcs) {
    $log->debug("Exasteel::Controller::Public_API::getAllInfo | Found VDC: ".Dumper(@vdcs)) if $log_level>1;
  }

  my $username=$vdcs[0]{ovmm_username};
  my $password=$vdcs[0]{ovmm_password};
  my $ovmm_endpoint=$vdcs[0]{ovmm_endpoint};
  my %result=();

  my $url='https://'.$username.':'.$password.'@'.$ovmm_endpoint.'/ovm/core/wsapi/rest/ServerPool';

  $log->debug("Exasteel::Controller::Public_API::getAllInfo | URL: ".$url) if $log_level>1;

  my $data=$ovmm_ua->get($url);
  if (my $res = $data->success) {
    # force XML semantics
    $res->dom->xml(1);
    $res->dom->find('server')->each(
      sub {
        if ($_->at('name')) { $result{'cn'}=$_->at('account')->text; }
        if ($_->at('biosVendor')) { $result{'biosVendor'}=$_->at('name')->text; }
      }
    );
  } else {
    $log->debug("Exasteel::Controller::Public_API::getAllInfo | Error in request to OVMM");
    $status{'status'}="ERROR";
    $status{'description'}="Error in request to OVMM";
  }

  if ($log_level>0) {
    $log->debug("Exasteel::Controller::Public_API::getAllInfo | Result: ".Dumper(\%result));
  }

  $self->respond_to(
    json => sub {
      if ($status{'status'} eq 'ERROR') {
        $self->render(json => \%status);
      } else {
        $self->render(json => \%result);
      }
    }
  );
}

"I came here to find the Southern Oracle (Neverending Story, 1984)";
