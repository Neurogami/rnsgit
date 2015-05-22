
begin
  require 'bones'
rescue LoadError
  abort '### Please install the "bones" gem ###'
end

task :default => 'test:run'
task 'gem:release' => 'test:run'

Bones {
  name     'rnsgit'
  authors  'James Britt '
  email    'james@neurogami.com '
  url      'htps://neurogami.com'
}

