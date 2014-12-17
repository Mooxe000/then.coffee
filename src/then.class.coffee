class Thenjs

  constructor: (start, debug) ->
    self = @
    # cont = undefined

    # 已经 是 一个 Thenjs 对象 直接返回
    return start  if start instanceof Thenjs
    # 如果是 then 的后续练，直接 实例化
    return new Thenjs start, debug  unless self instanceof Thenjs

    # 初始化 上下文环境
    self._success =
    self._each =
    self._eachSeries =
    self._parallel =
    self._series =
    self._finally =
    self._error =
    self._fail =
    self._result =
    self._nextThen =
    self._chain = null

    # 没有更多参数
    # 返回 上下文
    return self  unless arguments.length

    cont = genContinuation self, debug

    # 包装 成了 thunk
    start = toThunk start

    unless start?
      cont()
    else if typeof start is 'function'
      defer cont, start, cont
    else
      cont null, start

  @defer: defer

  @each: (array, iterator, debug) ->
    thenFactory (cont) ->
      defer cont, each, cont, array, iterator
    , null
    , debug

  @eachSeries: (array, iterator, debug) ->
    thenFactory (cont) ->
      defer cont, eachSeries, cont, array, iterator
    , null
    , debug

  @parallel: (array, debug) ->
    thenFactory (cont) ->
      defer cont, parallel, cont, array
    , null
    , debug

  @series: (array, debug) ->
    thenFactory (cont) ->
      defer cont, series, cont, array
    , null, debug

  @nextTick: (fn) ->
    args = slice arguments, 1
    nextTick ->
      fn.apply null, args

  # 全局 error 监听
  @onerror: (error) ->
    console.error 'Thenjs caught error: ', error
    throw error

  # **Thenjs** 对象上的 **finally** 方法，`all` 已废弃
  @::fin = @::finally = (finallyHandler) ->
    thenFactory (cont, self) ->
      self._finally = wrapTaskHandler cont, finallyHandler
    , @

  # **Thenjs** 对象上的 **then** 方法
  @::then = (successHandler, errorHandler) ->
    thenFactory (cont, self) ->
      self._success = wrapTaskHandler cont, successHandler
      self._error = errorHandler and wrapTaskHandler cont, errorHandler
    , @

  # **Thenjs** 对象上的 **fail** 方法
  @::fail = @::catch = (errorHandler) ->
    thenFactory (cont, self) ->
      self._fail = wrapTaskHandler(cont, errorHandler)
      # 对于链上的 fail 方法，如果无 error ，则穿透该链，将结果输入下一链
      self._success = ->
        cont.apply null, [null].concat slice arguments
    , @

  # **Thenjs** 对象上的 **each** 方法
  @::each = (array, iterator) ->
    thenFactory (cont, self) ->
      self._each = (dArray, dIterator) ->
        # 优先使用定义的参数，如果没有定义参数，则从上一链结果从获取
        # `dArray`, `dIterator` 来自于上一链的 **cont**，下同
        each cont, array or dArray, iterator or dIterator
    , @

  # **Thenjs** 对象上的 **eachSeries** 方法
  @::eachSeries = (array, iterator) ->
    thenFactory (cont, self) ->
      self._eachSeries = (dArray, dIterator) ->
        eachSeries cont, array or dArray, iterator or dIterator
    , @

  # **Thenjs** 对象上的 **parallel** 方法
  @::parallel = (array) ->
    thenFactory (cont, self) ->
      self._parallel = (dArray) ->
        parallel cont, array or dArray
    , @

  # **Thenjs** 对象上的 **series** 方法
  @::series = (array) ->
    thenFactory (cont, self) ->
      self._series = (dArray) ->
        series cont, array or dArray
    , @

  # **Thenjs** 对象上的 **toThunk** 方法
  @::toThunk = ->
    self = @
    (callback) ->
      if self._result
        callback.apply null, self._result
        self._result = false
      else self._finally = callback  if self._result isnt false
