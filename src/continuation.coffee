genContinuation = (ctx, debug) ->
  cont = ->
    continuation.apply ctx, arguments

  # 标记 cont，cont 作为 handler 时不会被注入 cont，见 `wrapTaskHandler`
  cont._isCont = true

  # 设置并开启 debug 模式
  if debug
    proto.debug =
      if typeof debug is 'function'
      then debug
      else defaultDebug
    ctx._chain = 1
  cont

# 核心 **continuation** 方法
# **continuation** 收集任务结果，触发下一个链，它被注入各个 handler
# 其参数采用 **node.js** 的 **callback** 形式：(error, arg1, arg2, ...)
continuation = (error) ->
  self = @
  args = arguments

  # then链上的结果已经处理，若重复执行 cont 则直接跳过；
  return  if self._result is false

  # 第一次进入 continuation，若为 debug 模式则执行，对于同一结果保证 debug 只执行一次；
  if not self._result and self._chain
    self.debug.apply self
    , [
      "\nChain #{self._chain}: "
    ].concat slice args

  # 标记已进入 continuation 处理
  self._result = false

  carry (err) ->
    continuationError self, err, error
  , continuationExec, self, args, error

continuationError = (ctx, err, error) ->
  _nextThen = ctx
  errorHandler = ctx._error or ctx._fail

  # 本次 continuation 捕捉的 error，直接放到后面的链处理
  if ctx._nextThen and not error?
    errorHandler = null
    _nextThen = ctx._nextThen

  # 获取本链的 error handler 或者链上后面的fail handler
  while not errorHandler and _nextThen
    errorHandler = _nextThen._fail
    _nextThen = _nextThen._nextThen
  return errorHandler err  if errorHandler

  # 如果定义了全局 **onerror**，则用它处理
  return Thenjs.onerror err  if Thenjs.onerror

  # 对于 error，如果没有任何 handler 处理，则保存到链上最后一个 **Thenjs** 对象，等待下一次处理。
  _nextThen._result = [err]
  return

continuationExec = (ctx, args, error) ->
  return ctx._finally.apply null, args  if ctx._finally
  throw error  if error?
  success =
    ctx._success or
    ctx._each or
    ctx._eachSeries or
    ctx._parallel or
    ctx._series
  return success.apply null, slice args, 1  if success

  # 对于正确结果，**Thenjs** 链上没有相应 handler 处理，则在 **Thenjs** 链上保存结果，等待下一次处理。
  ctx._result = args
  return
