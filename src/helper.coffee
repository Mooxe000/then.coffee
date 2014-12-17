# --------
#  Config
# --------
maxTickDepth = 100

# -------------
#  Base Helper
# -------------
toString = Object::toString

isArray = Array.isArray or
    (obj) ->
      toString.call obj is '[object Array]'

# 将 `arguments` 转成数组，效率比 `[].slice.call` 高很多
slice = (args, start) ->
  start = start or 0
  return []  if start >= args.length
  len = args.length
  ret = new Array len - start
  ret[len - start] = args[len]  while len-- > start
  ret

# --------
#  Helper
# --------

# 同步转异步，并发调用
# setTimeout 0
nextTick =
  if typeof setImmediate is 'function'
  then setImmediate
  else (fn) ->
    setTimeout fn, 0

# 同步执行函数，同时捕捉异常
# try catch
carry = (errorHandler, fn) ->
  try
    fn.apply null, slice arguments, 2
  catch error
    errorHandler error

# 异步执行函数，同时捕捉异常
# 调用 nextTick 转成异步并行
defer = (errorHandler, fn) ->
  args = arguments
  nextTick ->
    carry.apply null, args

# add for thunk
toThunk = (object) ->
  return object  unless object?
  return object.toThunk()  if typeof object.toThunk is 'function'
  if typeof object.then is 'function'
    (callback) ->
      object.then (res) ->
        callback null, res
      , callback
  else
    object

# 注入 cont，执行 fn，并返回新的 **Thenjs** 对象
thenFactory = (fn, ctx, debug) ->
  nextThen = new Thenjs()
  cont = genContinuation nextThen, debug

  # 注入 cont，初始化 handler
  fn cont, ctx
  return nextThen  unless ctx
  ctx._nextThen = nextThen
  nextThen._chain = ctx._chain + 1  if ctx._chain

  # 检查上一链的结果是否处理，未处理则处理，用于续接 **Thenjs** 链
  if ctx._result
    nextTick ->
      continuation.apply ctx, ctx._result
      return

  nextThen

# 封装 handler，`_isCont` 判定 handler 是不是 `cont`
# 不是则将 `cont` 注入成第一个参数
wrapTaskHandler = (cont, handler) ->
  return if handler._isCont
  then handler
  else ->
    args = slice arguments
    args.unshift cont
    handler.apply null, args

# 用于生成 `each` 和 `parallel` 的 `next`
parallelNext = (cont, result, counter, i) ->
  next = (error, value) ->
    return  if counter.finished
    if error?
      counter.finished = true
      return cont error
    result[i] = value
    --counter.i < 0 and cont null, result
  next._isCont = true
  next

# ## **each** 函数
# 将一组数据 `array` 分发给任务迭代函数 `iterator`
# 并行执行，`cont` 处理最后结果
each = (cont, array, iterator) ->
  # end = undefined
  result = []
  counter = {}
  return cont errorify array, 'each'  unless isArray(array)
  counter.i = end = array.length - 1
  return cont null, result  if end < 0
  i = 0

  while i <= end
    next = parallelNext cont, result, counter, i
    iterator next, array[i], i, array
    i++
  return

# ## **eachSeries** 函数
# 将一组数据 `array` 分发给任务迭代函数 `iterator`
# 串行执行，`cont` 处理最后结果
eachSeries = (cont, array, iterator) ->
  i = 0
  end = undefined
  result = []
  run = undefined
  stack = maxTickDepth

  next = (error, value) ->
    return cont error  if error?
    result[i] = value
    return cont null, result  if ++i > end

    # 先同步执行，嵌套达到 maxTickDepth 时转成一次异步执行
    run =
      if --stack > 0
      then carry
      else
        stack = maxTickDepth
        defer
    run cont, iterator, next, array[i], i, array
    return

  next._isCont = true
  return cont errorify array, 'eachSeries'  unless isArray array
  end = array.length - 1
  return cont null, result  if end < 0
  iterator next, array[0], 0, array
  return

# ## **parallel** 函数
# 并行执行一组 `array` 任务，`cont` 处理最后结果
parallel = (cont, array) ->
  # end = undefined
  result = []
  counter = {}

  return cont errorify array, 'parallel'  unless isArray array
  counter.i = end = array.length - 1
  return cont null, result  if end < 0

  i = 0
  while i <= end
    next = parallelNext cont, result, counter, i
    array[i] next, i, array
    i++
  return

# ## **series** 函数
# 串行执行一组 `array` 任务，`cont` 处理最后结果
series = (cont, array) ->
  i = 0
  end = undefined
  result = []
  run = undefined
  stack = maxTickDepth

  next = (error, value) ->
    return cont(error)  if error?
    result[i] = value
    return cont(null, result)  if ++i > end

    # 先同步执行，嵌套达到 maxTickDepth 时转成一次异步执行
    if --stack > 0
      run = carry
    else
      stack = maxTickDepth
      run = defer
    run cont, array[i], next, i, array
    return

  next._isCont = true
  return cont errorify array, 'series'  unless isArray array
  end = array.length - 1
  return cont null, result  if end < 0
  array[0] next, 0, array
  return

# 默认的 `debug` 方法
defaultDebug = ->
  console.log.apply console, arguments
  return

# 参数不合法时生成相应的错误
errorify = (obj, method) ->
  new Error "The argument #{obj and obj.toString()} in '#{method}' is not Array!"
