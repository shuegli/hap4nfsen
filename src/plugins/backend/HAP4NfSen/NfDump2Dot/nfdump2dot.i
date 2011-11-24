%module NfDump2Dot
%{
extern int nfdump2dot (char* input, char* output, char* ip, char* role_nums, bool, bool, bool, bool);

%}
extern int nfdump2dot (char* input, char* output, char* ip, char* role_nums, bool, bool, bool, bool);
