Pod::Spec.new do |s|
  s.name      = 'CBOperationStack'
  s.version   = '0.1.1'

  s.summary   = 'A LIFO (last in, first out) implementation of Apple's NSOperationQueue.'
  s.description = 'A LIFO (last in, first out) implementation of Apple's NSOperationQueue. It has the same interface as NSOperationQueue, with the addition of one method, addOperationAtBottomOfStack:(NSOperation*)op, which effectively allows you to use it as you would NSOperationQueue. '

  s.homepage  = 'https://github.com/cbrauchli/CBOperationStack'
  s.authors   = { 'Chris Brauchli' => 'chris@brauchli.me' }
  s.source   = { :git => 'git@github.com:cbrauchli/CBOperationStack.git', :tag => '0.1.1' }

  s.platform  = :ios
  s.requires_arc = true

  s.license   = {
    :type => 'MIT',
    :file => 'MIT-LICENSE'
  }

  s.source_files = ['*.h', '*.m']
end