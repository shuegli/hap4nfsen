#include <stdio.h>
#include <stdint.h>
#include <string>
#include <set>
#include <vector>
#include <boost/algorithm/string.hpp>
#include <boost/lexical_cast.hpp>
#include "ginterface.h"
using namespace std;

int nfdump2dot (char* input, char* output, char* ip, char* role_nums, bool summarize_client_roles=true, bool summarize_multi_client_roles=true, bool summarize_server_roles=true, bool summarize_p2p_roles=true){
	// return immediately if parameters are empty
	if(!input)
		return 1;
	if(!output)
		return 2;
	if(!ip)
		return 3;
	if(!role_nums)
		return 4;

	// needed for the references
	std::string in_filename = input;
	std::string outfilename = output;
	std::string IP_str = ip;
	std::string role_num_str = role_nums;

	// parse role number string
	set<uint32_t> role_num_set;
	vector<string> parts;
	boost::split(parts, role_num_str, boost::is_any_of(","));
	try {
		for (vector<string>::const_iterator it = parts.begin(); it!=parts.end(); ++it) {
			if ((*it) == "") {
				continue;
			}
			role_num_set.insert(boost::lexical_cast<uint32_t>(*it));
		}
	} catch (boost::bad_lexical_cast const& e) {
		cerr << "unable to convert role number string to role numbers:" << e.what() << endl;
		return 5;
	}

	// do not try to summarize multi-client roles when not even client-roles are summarized (Bug in haplib?)
	if(!summarize_client_roles)
		summarize_multi_client_roles = false;

	// create the binary represantation of the summary-flags
	int sum = 1*summarize_client_roles + 2*summarize_multi_client_roles + 4*summarize_server_roles + 8*summarize_p2p_roles;
	CInterface::summarize_flags_t sum_flags = *((CInterface::summarize_flags_t*)(void*)(&sum));

	CInterface libif;
	bool ok = libif.get_graphlet(in_filename, outfilename, IP_str, sum_flags, (CInterface::filter_flags_t)0, role_num_set);

	if(!ok)
		return 6;

	return 0;
}
