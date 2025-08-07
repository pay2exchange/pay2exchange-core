#include <iostream>

int main(const int argc, const char **argv) {
	for (int i=0; i<argc; ++i) std::cout<<"Arg #"<<i<<" is: [" << argv[i] << "]\n";
}
