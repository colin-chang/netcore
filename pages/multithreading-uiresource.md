# UI资源跨线程调用

在`WinForm`或`WPF`程序中，默认只允许在创建控件的线程(一般为UI线程)中访问控件，如果想在其他线程中访问UI资源，需要做特殊处理。

## 1. WPF
`Window`类有一个`Dispatcher`对象，该对象是一个队列，用来保存应用程序主线程需要执行的任务。其他线程需要访问UI资源时只需要将操作加入到`Dispatcher`中，然后由主线程负责代为执行。

```csharp
private void Button_Click(object sender, RoutedEventArgs e)
{
    new Thread(() => ChangeText()).Start();
}

private void ChangeText()
{
    Random rdm = new Random();
    string num = rdm.Next().ToString();
    
    //当前线程不是主线程
    if (Dispatcher.Thread != Thread.CurrentThread)
    {
        Dispatcher.Invoke(new Action<string>(s => txt.Text = s), num);
    }
    //当前线程是主线程
    else
        txt.Text = num;
}
```

## 2. WinForm
`WinForm`当中，我们有两种方式来解决UI资源跨线程访问的问题。

在`Form`构造函数中设置`CheckForIllegalCrossThreadCalls = false`，禁止窗体进行非法跨线程调用的校验，这只是屏蔽了非法校验，并没有真正解决问题，不推荐使用。

推荐使用以下方式：

```csharp
private void button1_Click(object sender, EventArgs e)
{
    new Thread(() => ChangeText()).Start();
}
private void ChangeText()
{
    Random rdm = new Random();
    string num = rdm.Next().ToString();
    //当前线程是创建此控件的线程
    if (txt.InvokeRequired)
        txt.Invoke(new Action<string>(s => txt.Text = s), num);
    //当前线程不是创建此控件的线程
    else
        txt.Text = num;
}
```