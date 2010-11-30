function varargout = rand_seeded(varargin)
    schedulerOrchestra.seed_randstream;
    varargout = cell(1, max(nargout, 1));
    [varargout{:}] = rand(varargin{:});
