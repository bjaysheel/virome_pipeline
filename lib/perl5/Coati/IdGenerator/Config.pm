package Coati::IdGenerator::Config;

## This config file defines the module that will be used for id generation by coati
## The specified class should at least implement all methods defined in Coati::IdGenerator

use Coati::IdGenerator::IGSIdGenerator;
our $class = 'Coati::IdGenerator::IGSIdGenerator';

1;
