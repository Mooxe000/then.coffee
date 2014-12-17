# global module, process, Promise
Thenjs = require '../dist/then.js'
Thenjs.onerror = null

slice = [].slice

getArray = (length) ->
  # 生成有序数组
  a = []
  while length > 0
    a.push a.length
    length--
  a

asnycTask = ->
  # 虚拟异步回调任务，最后一个参数为callback，异步返回callback之前的所有参数
  args = slice.call arguments
  callback = args.pop()
  Thenjs.nextTick ->
    callback.apply null, args

testThen = (test, num) ->
  Thenjs

  .parallel [ # 并行
    (cont) ->
      asnycTask null, num, cont
    (cont) ->
      asnycTask null, num + 1, cont
    (cont) ->
      asnycTask null, num + 2, cont
  ]

  .then (cont, result) ->

    test.deepEqual result, [
      num
      num + 1
      num + 2
    ], 'Test parallel'
    asnycTask null, cont

  .series [ # 串行
    (cont) ->
      asnycTask null, num + 3, cont
    (cont) ->
      asnycTask null, num + 4, cont
  ]

  .then (cont, result) ->

    test.deepEqual result, [
      num + 3
      num + 4
    ], 'Test series'
    asnycTask num, cont

  .then ->
    return
  , (cont, err) ->
    test.strictEqual err, num, 'Test errorHandler'
    asnycTask num, num, cont

  .fin (cont, err, result) ->
    test.strictEqual err, num, 'Test finally'
    test.equal result, num
    cont null, [
      num
      num + 1
      num + 2
    ]

  .each null, (cont, value, index) ->
    test.equal value, num + index
    asnycTask null, value, cont

  .then (cont, result) ->

    test.deepEqual result, [
      num
      num + 1
      num + 2
    ], 'Test each'

    asnycTask null, [
      num
      num + 1
      num + 2
    ], (cont, value, index) ->
      test.equal value, num + index
      asnycTask null, value, cont
    , cont

  .eachSeries null, null

  .then (cont, result) ->

    test.deepEqual result, [
      num
      num + 1
      num + 2
    ], 'Test eachSeries'

    throw num

  .then ->
    test.ok false, 'This should not run!'

  .fail (cont, err) ->
    test.strictEqual err, num, 'Test fail'
    asnycTask null, num, cont

exports.testThen = (test) ->
  list = getArray 1000

  test0 =
    Thenjs()
    .then (cont) ->

      Thenjs 1
      .fin (cont2, error, value) ->
        test.strictEqual error, null
        test.strictEqual value, 1
        cont()

    .then (cont) ->
      a = Thenjs(1)
      test.strictEqual a, Thenjs(a)
      a.then (cont2, value) ->
        test.strictEqual value, 1
        a.then (cont3, value) ->
          test.ok false, 'This should not run!'
        cont()

    .then (cont) ->
      if typeof Promise is 'function'
        p1 = Promise.resolve(true)
        Thenjs(p1).then (cont2, value) ->
          test.strictEqual value, true
          p2 = Promise.reject(false)
          Thenjs(p2).fail (cont3, error) ->
            test.strictEqual error, false
            cont()
      else
        cont()

  test1 = test0.each list, (cont, value) ->
    testThen(test, value).fin (cont2, error, result) ->
      cont error, result

  test2 = test1.eachSeries null, (cont, value) ->
    testThen(test, value).fin cont

  test3 = test2.then (cont, result) ->

    test.deepEqual result, list, 'Test each and eachSeries'

    Thenjs 1
    .toThunk() (err, value) ->
      test.strictEqual err, null
      test.strictEqual value, 1

    thunk = Thenjs (cont2) ->
      Thenjs.nextTick (a, b) ->
        test.strictEqual a, 1
        test.strictEqual b, 2
        cont2 null, [
          a
          b
        ]
      , 1, 2
    .toThunk()

    Thenjs(thunk)
    .then (cont2, result) ->
      test.deepEqual result, [
        1
        2
      ]
      cont list

  Thenjs.nextTick ->
    test3.fail (cont, err) ->
      test.strictEqual err, list, 'None error'
      test.done()
