# zcu
Скрипты не являются готовым решением, а выступают как пример, котрый необходимо настроить

Скрипт, zimbraMUL, достает из системы zimbra, все uid, email пользователя для которого zimbraCOS "student". Созданный файл используется для создания пользователя. 
Скрипт, zimbraUI, обновляет информацию о пользователе в системе, как ключ используется № uid из файла ЕДЕБО, то есть, в zimbra должен храниться этот номер. В скриптах на создание он заносится в поле "facsimileTelephoneNumber". Скриптом, zimbraMUL, мы достаем для каждого пользователя, у которого zimbraCOS = student, email, uid(№ ЕДЕБО).
