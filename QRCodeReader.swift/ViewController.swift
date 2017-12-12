/*
 * QRCodeReader.swift
 *
 * Copyright 2014-present Yannick Loriot.
 * http://yannickloriot.com
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 */

import AVFoundation
import Alamofire
import UIKit

class ViewController: UIViewController, UIScrollViewDelegate, QRCodeReaderViewControllerDelegate {
    
  @IBOutlet weak var previewView: QRCodeReaderView!
   @IBOutlet weak var bottom: NSLayoutConstraint!
    @IBOutlet weak var bottom2: NSLayoutConstraint!
    @IBOutlet weak var QrReader: UIButton!
    @IBOutlet weak var WaitAnimation: UIActivityIndicatorView!
    @IBOutlet weak var SendPhoto: UIButton!
  lazy var reader: QRCodeReader = QRCodeReader()
  lazy var readerVC: QRCodeReaderViewController = {
    let builder = QRCodeReaderViewControllerBuilder {
      $0.reader = QRCodeReader(metadataObjectTypes: [AVMetadataObject.ObjectType.qr], captureDevicePosition: .back)
      $0.showTorchButton = true
    }
    
    return QRCodeReaderViewController(builder: builder)
  }()

    
    var currentImage = 0
    var countImage = 0
    var countSendImage = 0
    var photoForSend: Dictionary<Int, Bool> = [:]
    var isBlocked = 0
  // MARK: - Actions

    
    
  private func checkScanPermissions() -> Bool {
    do {
      return try QRCodeReader.supportsMetadataObjectTypes()
    } catch let error as NSError {
      let alert: UIAlertController

      switch error.code {
      case -11852:
        alert = UIAlertController(title: "Error", message: "Необходимо разрешить использование камеры в настройках", preferredStyle: .alert)

        alert.addAction(UIAlertAction(title: "Setting", style: .default, handler: { (_) in
          DispatchQueue.main.async {
            if let settingsURL = URL(string: UIApplicationOpenSettingsURLString) {
              UIApplication.shared.openURL(settingsURL)
            }
          }
        }))

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
      default:
        alert = UIAlertController(title: "Error", message: "QR-ридер не поддерживается на вашем устройстве", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
      }

      present(alert, animated: true, completion: nil)

      return false
    }
  }

    private func configureButton(_ button: UIButton) {
        //button.backgroundColor = UIColor(red: 115/255, green: 199/255, blue: 108/255, alpha: 1.0)
        button.backgroundColor = UIColor(red: 241/255, green: 73/255, blue: 21/255, alpha: 1.0)
        button.setTitleColor(UIColor.white, for: .normal)
        button.setTitleColor(UIColor.lightGray, for: .highlighted)
        //let front = UIFont(name: "GillSans-SemiBold", size: 20)
       // button.titleLabel?.font = front
        button.layer.cornerRadius = 6.0
        //button.titleLabel?.font = UIFont(name: "ChalkboardSE-Bold", size: 20)
        button.layer.shadowOpacity = 0.1
        button.layer.shadowOffset = CGSize(width: 2, height: 2)
        button.layer.shadowRadius = 1
        
        button.titleLabel?.layer.shadowOpacity = 1.0
        button.titleLabel?.layer.shadowOffset = CGSize(width: 1, height: 1)
        button.titleLabel?.layer.shadowRadius = 0
    }
    
    private func configureLabel(_ label: UILabel, _ head: Bool) {

        if (head)
        {
            //label.layer.shadowOpacity = 1.0
            //label.layer.shadowOffset = CGSize(width: 0, height: 0)
            //label.layer.shadowRadius = 0
            let front = UIFont(name: "GillSans-SemiBold", size: 22)
            label.font = front
        }
        else
        {
           // label.layer.shadowOpacity = 1.0
          //  label.layer.shadowOffset = CGSize(width: 1, height: 1)
            //label.layer.shadowRadius = 0
            let front = UIFont(name: "GillSans", size: 22)
            label.font = front
            
        }
        
        
    }
    
    let once_margin_top = 10        // Одиночный отступ от верхнего края экрана
    let button_h = 30               // Высота кнопки (считать QR-код или отправить фото)
    let label_margin_top = 10       // Отступ над label
    let label_h = 20                // Высота текстогово поля
    let photo_margin_top = 10       // Отступ перед фотографией
    var image_h = 0                 // Высота фотографии (относительная ширины экрана)
    var image_w = 0                 // Ширина фотографии (относительно ширины экрана)
    var label_w = 0                 // Ширина лейбла
    var button_w = 0                // Ширина кнопки
    var head_h = 0                  // Высота шапки (относительная)
    var pos_h = 0                   // Высота одной позиции вложения (лейбл + фотка + отступ)
    var allHeight = 0               // Полная высота ScrollView
    var maxH:Int = 0                // Высота экрана в пикселях
    var maxW:Int = 0                // Ширина экрана в пикселях
    let margin_left = 20            // Стандартный отступ от левой границы
    let close_w = 30                // Ширина кнопки удаления фотографии
    let close_h = 30                // Высота кнопки удаления фотографии
    var errorWhenSendPhoto: Bool = false;
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let screenSize: CGRect = UIScreen.main.bounds
        maxW = Int(screenSize.width)                                // Ширина экрана в пикселях
        maxH = Int(screenSize.height)                               // Высота экрана в пикселях
        head_h = once_margin_top+button_h+label_margin_top+label_h  // Высота шапки в пикселях
        image_w = Int(CGFloat(maxW)*0.8)                            // Ширина картинки, относительная
        image_h = Int(CGFloat(image_w)*0.6)                         // Высота изображения, относительная
        pos_h = label_margin_top+label_h+photo_margin_top+image_h   // Высота одной позиции с фотографией
        button_w = (maxW - 3*margin_left)/2                         // Ширина кнопки
        label_w = maxW-2*margin_left                                // Ширина тестового поля
        
        fonts[1]="Zapfino"
        fonts[2]="PartyLetPlain"
        fonts[3]="BanglaSangamMN-Bold"
        fonts[4]="ChalkboardSE-Bold"
        fonts[5]="GillSans-SemiBold"
        fonts[6]="ChalkboardSE-Light"
        fonts[7]="ChalkboardSE-Regular"
        fonts[8]="Courier"
        fonts[9]="Courier-Bold"
        fonts[10]="Courier-BoldOblique"
        fonts[11]="Courier-Oblique"
        
        
        print("Hi there, Master")
        
        
        var button = UIButton(frame: CGRect(x: margin_left, y: once_margin_top, width: button_w, height: button_h))
        button.setTitle("QR-код", for: .normal)
        button.titleLabel?.adjustsFontSizeToFitWidth = true
        button.addTarget(self, action: #selector(scanInModalAction), for: .touchUpInside)
        let myView  = self.view.viewWithTag(-42) as? UIView
        myView!.addSubview(button)
        configureButton(button)
        button = UIButton(frame: CGRect(x: button_w+2*margin_left, y: once_margin_top, width: button_w, height: button_h))
        button.setTitle("Отправить фото", for: .normal)
        button.addTarget(self, action: #selector(uploadWithAlamofire), for: .touchUpInside)
        button.titleLabel?.adjustsFontSizeToFitWidth = true
        myView!.addSubview(button)
        configureButton(button)
        
        let ScrollView  = self.view.viewWithTag(-420) as? UIScrollView
        ScrollView!.canCancelContentTouches = true
        ScrollView!.delaysContentTouches = true
        UnBlockScreen()
        //SendPhoto.isEnabled = false
        //bottom.constant = 100
    }
    
  @IBAction func scanInModalAction(_ sender: AnyObject) {
   
    let this = self
    guard checkScanPermissions() else { return }
    
     readerVC.modalPresentationStyle = .formSheet
     readerVC.delegate               = self
    
     readerVC.completionBlock = { (result: QRCodeReaderResult?) in
         //if let result = result {
         //print("Hmm : \(result.value) of type \(result.metadataType)")
         //   this.SendGetRequest(result.value)
         //   }
         }
    
     present(readerVC, animated: true, completion: nil)
  }
    
    func SendGetRequest(_ code: String)
    {
        var URL = """
https://capf.comfy.ua/mpos/comply-rivals/codes/qr/
"""
        URL = URL + code
        URL = URL + """
        /info
        """
        
        let response = request(URL).responseJSON()
        { response in
            do
            {
                let Data = String(data: response.data!, encoding: String.Encoding(rawValue: String.Encoding.utf8.rawValue))! //String(describing: )
                
                let statusCode = response.response?.statusCode
                //let temp = response
                //let temp2 = temp.data
                //let temp3 = temp2?.description
                
                
                if (statusCode != 200)
                {
                    var title: String = ""
                    var message: String = ""
                    var submit: String = ""
                    if (statusCode == 422)
                    {
                        title = "Ошибка"
                        message = "Код уже устарел или не существует, пересоздайте код  в 1C."
                        submit = "Закрыть"
                        self.CreateAlert(title,message,submit)
                    }
                    else
                    {
                        if (statusCode != nil)
                        {
                            title = "Ошибка"
                            message = "При считывании QR-кода произошла ошибка " + String(describing: statusCode!)+"."
                            submit = "Закрыть"
                            self.CreateAlert(title,message,submit)
                        }
                        else
                        {
                            title = "Ошибка"
                            message = "При считывании QR-кода произошла неизвестная ошибка."
                            submit = "Закрыть"
                            self.CreateAlert(title,message,submit)
                        }
                    }
                    self.DeleteOldStruct()
                    self.UnBlockScreen()
                    return
                }
                
                //let temp = Data.replacingOccurrences(of: "\"", with: "")
                let sttr = """
{"attributes":{"BaseCode":"APL","DocumentType":"Заказ","DocumentNum":"3695","DocumentDate":"20170815","CommonScans":[{"name":"Фото3695_1","path":"//SkanDocsFromPos//KIY//Konk//%D0%A6%D0%9A_03.11.17_69513432_1025342.jpg"},{"name":"Фото3695_2","path":"//SkanDocsFromPos//KIY//Konk//%D0%A6%D0%9A_03.11.17_69513432_1025342.jpg"}],"Lines":[{"ItemID":"1005431","LineNumber":1,"Scans":[{"name":"Фото1005431_1","path":"//SkanDocsFromPos//KIY//Konk//%D0%A6%D0%9A_03.11.17_69513432_1025342.jpg"},{"name":"Фото1005431_2","path":"//SkanDocsFromPos//KIY//Konk//%D0%A6%D0%9A_03.11.17_69513432_1025342.jpg"}]},{"ItemID":"1020444","LineNumber":2,"Scans":[{"name":"Фото1020444_1","path":"//SkanDocsFromPos//KIY//Konk//%D0%A6%D0%9A_03.11.17_69513432_1025342.jpg"},{"name":"Фото1020444_2","path":"//SkanDocsFromPos//KIY//Konk//%D0%A6%D0%9A_03.11.17_69513432_1025342.jpg"},{"name":"Фото1020444_3","path":"//SkanDocsFromPos//KIY//Konk//%D0%A6%D0%9A_03.11.17_69513432_1025342.jpg"}]},{"ItemID":"1020304","LineNumber":3,"Scans":[{"name":"Фото1020304_1","path":"//SkanDocsFromPos//KIY//Konk//%D0%A6%D0%9A_03.11.17_69513432_1025342.jpg"}]},{"ItemID":"1234567","LineNumber":4,"Scans":[{"name":"Фото1234567_1","path":"//SkanDocsFromPos//KIY//Konk//%D0%A6%D0%9A_03.11.17_69513432_1025342.jpg"},{"name":"Фото1234567_2","path":"//SkanDocsFromPos//KIY//Konk//%D0%A6%D0%9A_03.11.17_69513432_1025342.jpg"},{"name":"Фото1234567_3","path":"//SkanDocsFromPos//KIY//Konk//%D0%A6%D0%9A_03.11.17_69513432_1025342.jpg"},{"name":"Фото1234567_4","path":"//SkanDocsFromPos//KIY//Konk//%D0%A6%D0%9A_03.11.17_69513432_1025342.jpg"}]}]}}
"""
                let inputData =  Data.data(using: .utf8)!
                //let inputData =  sttr.data(using: .utf8)!
                let decoder = JSONDecoder()
                let stat = try! decoder.decode(jsonResult.self, from: inputData)
                dump (stat)
                let encoder = JSONEncoder ()
                encoder.outputFormatting = .prettyPrinted
                let data = try! encoder.encode(stat)
                let json = String(data: data, encoding: .utf8)!
                
                self.BuildStruct(stat)
                self.UnBlockScreen()
                
                let alert = UIAlertController(
                    title: "It's ok",
                    message: String (json),
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
                
            }
            catch
            {
                self.UnBlockScreen()
                let alert = UIAlertController(
                    title: "Error!",
                    message: String (describing: response.data),
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
                print(response.data)
            }
        }
        response.resume()
        BlockScreen()
    }
    
    func CreateAlert(_ title: String, _ message: String, _ submit: String)
    {
        let alert = UIAlertController(
            title: title,
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: submit, style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }
    
    
    func DeleteOldStruct()
    {
        if (countImage < 1) {return}
        var tag = 0
        for index in 1...countImage
        {
            tag = 1 + index*1000
            DeleteElement(tag)
            tag = 10 + index*1000
            DeleteElement(tag)
            tag = 100 + index*1000
            DeleteElement(tag)
            if (photoForSend[index] != nil)
            {
                photoForSend.removeValue(forKey: index)
            }
            //SendPhoto.isEnabled = false
        }
        
        var label = self.view.viewWithTag(-100) as? UIView
        while (label != nil)
        {
            label?.removeFromSuperview()
            label = self.view.viewWithTag(-100) as? UIView
        }
    }
    
    func DeleteElement(_ tag:Int)
    {
        var element = self.view.viewWithTag(tag)
        element?.removeFromSuperview()
    }

    func BuildStruct(_ response: jsonResult)
    {
        var count = 1
        
        self.DeleteOldStruct()
        var BaseCode = ""
        var DocumentType = ""
        var DocumentDate  = ""
        var DocumentNum = ""
        if (response.attributes?.BaseCode != nil)
        {
            BaseCode = (response.attributes?.BaseCode)!
        }
        if (response.attributes?.DocumentType != nil)
        {
            DocumentType = (response.attributes?.DocumentType)!
        }
        if (response.attributes?.DocumentDate != nil)
        {
            DocumentDate = (response.attributes?.DocumentDate)!
        }
        if (response.attributes?.DocumentNum != nil)
        {
            DocumentNum = (response.attributes?.DocumentNum)!
        }
        
        
        let head:String = BaseCode + DocumentType+DocumentDate+DocumentNum//(((response.attributes?.BaseCode)?)! + (response.attributes?.DocumentType)? + (response.attributes?.DocumentDate)? + ((response.attributes?.DocumentNum)?)!)!
        CreateLabel(margin_left,once_margin_top+button_h+label_margin_top,head,false)
        if (response.attributes?.CommonScans != nil)
        {
            for (scans) in (response.attributes?.CommonScans)!
            {
                CreatePos(count,scans.name!,scans.path!)
                count += 1
            }
        }
        if (response.attributes?.Lines != nil)
        {
            for (lines) in (response.attributes?.Lines)!
            {
                var itemId = lines.ItemID
                if (lines.Scans != nil)
                {
                    for (scans) in (lines.Scans)!
                    {
                        CreatePos(count,scans.name!,scans.path!)
                        count += 1
                    }
                }
            }
        }
        countImage = count - 1
        
        allHeight = head_h + countImage*pos_h - maxH
        
        var tmp = CGFloat(head_h + countImage*pos_h-maxH)
        
        tmp = tmp + 30
        if (tmp < CGFloat(maxH))
        {
            tmp = tmp-bottom2.constant
        }
        
        allHeight = allHeight + 30
        if (allHeight < maxH)
        {
            allHeight = allHeight-Int(bottom2.constant)
        }
        bottom.constant = tmp//CGFloat(allHeight)
        bottom2.constant = tmp//CGFloat(allHeight)
    }
    
    func CreatePos(_ count: Int, _ name: String, _ path: String)
    {
        var y = head_h + (count-1)*pos_h+label_margin_top
        CreateLabel(margin_left, y, name,true)
        y = y+label_h + label_margin_top
        CreateImage(count, y, path)
    }
    
    
    
    func CreateCamBtn(_ count: Int,_ x: Int, _ y: Int, _ w: Int, _ h:Int)
    { // Создание прозрачной кнопки поверх картинки, чтобы реагировать на нажатие на эту картинку
        var button = UIButton(frame: CGRect(x: x, y: y, width: w, height: h))
        button.addTarget(self, action: #selector(camButtonTapped), for: .touchUpInside)
        button.tag = 1 + count * 1000
        let myView  = self.view.viewWithTag(-42) as? UIView
        myView!.addSubview(button)
    }
    /*
    func CreateGalBtn(_ count: Int,_ x: Int, _ y: Int, _ w: Int, _ h:Int)
    {
        var button = UIButton(frame: CGRect(x: x, y: y, width: w, height: h))
        button.setTitle("Галерея", for: .normal)
        button.addTarget(self, action: #selector(galButtonTapped), for: .touchUpInside)
        button.titleLabel?.adjustsFontSizeToFitWidth = true
        button.tag = 10 + count * 1000
        let myView  = self.view.viewWithTag(-42) as? UIView
        myView!.addSubview(button)
        configureButton(button)
    }
    */
    func CreateBtn(_ x: Int, _ y: Int, _ w: Int, _ h: Int, _ tag: Int, _ z_Index: CGFloat)
    {// Создание кнопки, удаляющей текущую картинку
        var button = UIButton(frame: CGRect(x: x, y: y, width: w, height: h))
        button.addTarget(self, action: #selector(DeleteImage), for: .touchUpInside)
        //button.setBackgroundImage(UIImage(named: "Close-icon.png"), for: UIControlState.normal)
        //button.layer.shadowOpacity = 0.6
        //button.layer.shadowOffset = CGSize(width: 2, height: 2)
        //button.layer.shadowRadius = 2
        button.setTitle("X", for: .normal)
        button.backgroundColor = UIColor(red: 255/255, green: 255/255, blue: 255/255, alpha: 0.5)
        button.tag = tag*1000
        let myView  = self.view.viewWithTag(-42) as? UIView
        myView!.addSubview(button)
        button.setTitleColor(UIColor.black, for: .normal)
        button.setTitleColor(UIColor.lightGray, for: .highlighted)
        button.layer.zPosition = z_Index+11
        button.isHidden = true
    }
    
    func CreateImage(_ count:Int, _ y: Int, _ str:String)
    {// Создание изображения, на котором будет отображаться фотка
        var image = UIImageView(frame: CGRect(x: (maxW-image_w)/2, y: y, width: image_w, height: image_h))
        image.backgroundColor = .white
        image.layer.cornerRadius = 6.0
        image.layer.shadowOpacity = 0.6
        image.layer.shadowOffset = CGSize(width: 2, height: 2)
        image.layer.shadowRadius = 2
        image.tag = 100 + count * 1000
        image.accessibilityIdentifier = str
        image.isUserInteractionEnabled = true
        
        let myView  = self.view.viewWithTag(-42) as? UIView
        myView!.addSubview(image)
        CreateCamBtn(count, (maxW-image_w)/2, y, image_w, image_h)
        image.image = UIImage(named: "placeholder.png")
        CreateBtn((maxW-image_w)/2+image_w-close_w, y, close_w, close_h, image.tag, image.layer.zPosition+20) // Кнопка удаления текущего изображения
    }
    
    func CreateLabel(_ x:Int,_ y: Int, _ head: String, _ color: Bool)
    {
        var label = UILabel(frame: CGRect(x: x, y: y, width: label_w, height: label_h))
        label.text = head
        let myView  = self.view.viewWithTag(-42) as? UIView
        label.tag = -100
        label.textAlignment = NSTextAlignment.left
        label.textAlignment = .left
        if (color)
        {
            label.textColor = UIColor(red: 115/255, green: 199/255, blue: 108/255, alpha: 1.0)
        }
        else
        {
            label.textColor = UIColor(red: 0/255, green: 0/255, blue: 0/255, alpha: 1.0)
        }
        
        //label.shadowColor = UIColor.black
        //label.font = UIFont(name: "Arial", size: CGFloat(22))
        myView!.addSubview(label)
        configureLabel(label, color)
        
        /*button.backgroundColor = .black
        button.setTitle("Галерея", for: .normal)
        button.addTarget(self, action: #selector(galButtonTapped), for: .touchUpInside)
        button.tag = 10 + count * 1000
        self.view.addSubview(button)*/
    }
    
    @IBAction func uploadWithAlamofire(_ sender: AnyObject)
    {
        countSendImage = photoForSend.count
        errorWhenSendPhoto = false
        if (countSendImage == 0)
        {
            let title: String = ""
            let message: String = "Отсутствуют фото для отправки!"
            let submit: String = "Закрыть"
            self.CreateAlert(title,message,submit)
            return
        }
        BlockScreen()
        if (countImage < 1) {return}
        for index in 1...countImage
        {
            if (photoForSend[index] != nil && photoForSend[index] == true)
            {
                SendSinglePhoto(index)
            }
        }
    }
    
    func BlockScreen()
    {
        if (isBlocked == 0)
        {
            isBlocked = 1
            let screenSize: CGRect = UIScreen.main.bounds
            let ScrollView  = self.view.viewWithTag(-420) as? UIScrollView
            let MyView = self.view.viewWithTag(-42) as? UIView
            var placeholder2 = UIImageView(frame: CGRect(x: 0, y: 0, width: screenSize.width, height: screenSize.height))
            placeholder2.backgroundColor = UIColor(red: 255/255, green: 255/255, blue: 255/255, alpha: 0.7)
            placeholder2.layer.cornerRadius = 6.0
            placeholder2.layer.shadowOpacity = 0.6
            placeholder2.layer.shadowOffset = CGSize(width: 2, height: 2)
            placeholder2.layer.shadowRadius = 2
            placeholder2.tag = -3
            MyView!.addSubview(placeholder2)
            placeholder2.layer.zPosition = 50
            ScrollView!.isUserInteractionEnabled = false
            let loading  = self.view.viewWithTag(-13) as? UIActivityIndicatorView
            loading!.layer.zPosition = 100
            loading!.isHidden = false
            loading!.startAnimating()
        }
    }
    
    func UnBlockScreen()
    {
        var placeholder  = self.view.viewWithTag(-3) as? UIView
        while (placeholder != nil)
        {
            placeholder!.removeFromSuperview()
            placeholder  = self.view.viewWithTag(-3) as? UIView
        }
        
        let loading  = self.view.viewWithTag(-13) as? UIActivityIndicatorView
        loading!.layer.zPosition = 0;
        loading!.isHidden = true
        loading!.stopAnimating()
        
        let ScrollView  = self.view.viewWithTag(-420) as? UIScrollView
        ScrollView!.isUserInteractionEnabled = true
        isBlocked = 0
    }
    
    func CheckUpload()
    {
        if (countSendImage == 0)
        {
            UnBlockScreen()
            if (!errorWhenSendPhoto)
            {
               CreateAlert("","Фотографии успешно загружены","Закрыть")
            }
        }
    }
    
    func SendSinglePhoto(_ count: Int)
    {
        var imageView = self.view.viewWithTag(100 + count * 1000) as? UIImageView
        
        let image = imageView?.image
        

       let baseURL = """
https://capf.comfy.ua/mpos/comply-rivals/applications/storage/file
"""
        let endURL = imageView!.accessibilityIdentifier!.replacingOccurrences(of: "\\", with: "/", options: .literal, range: nil)
        
        let url = baseURL + endURL
        
        var URL = String(describing: url.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed)!)

        let compressionQuality: CGFloat = 0.2
        guard let imageData = UIImageJPEGRepresentation(image!, compressionQuality) else {
            print("Unable to get JPEG representation for image \(image)")
            return
        }
        
        let headers = [
            "Content-Type": "image/jpeg"
        ]
        
        // presignedUrl is a String
        BlockScreen()
        Alamofire.upload(imageData, to: URL, method: .put, headers: headers)
            .responseData {
                response in
                
                guard let httpResponse = response.response else {
                    self.UnBlockScreen()
                    if (!self.errorWhenSendPhoto)
                    {
                        self.CreateAlert("Ошибка","При отправке произошла ошибка","Закрыть")
                    }
                    return
                }
                let statusCode = httpResponse.statusCode
                if (statusCode != 204)
                {
                    if (!self.errorWhenSendPhoto)
                    {
                        if (statusCode == 422)
                        {
                            self.CreateAlert("Ошибка", "Путь файла устарел или не существует. Пересоздайте код в 1С.", "Закрыть")
                        }
                        else
                        {
                            self.CreateAlert("Ошибка", "При отправке изображений произошла ошибка " + String(statusCode)+".", "Закрыть")
                        }
                        self.errorWhenSendPhoto = true
                    }
                    //self.countSendImage = self.countSendImage - 1
                    //self.UnBlockScreen()
                    //return
                }
                self.countSendImage = self.countSendImage - 1
                self.CheckUpload()
        }
       /* Alamofire.upload(multipartFormData:
            {
                (multipartFormData) in
                multipartFormData.append(UIImageJPEGRepresentation(image!, 0.1)!, withName: "image", fileName: "file.jpeg", mimeType: "image/jpeg")
        }, to: url2, method: .put, headers: ["Content-type":"image/jpeg"])
        { (result) in
            switch result {
            case .success(let upload,_,_ ):
                upload.uploadProgress(closure: { (progress) in
                    //Print progress
                })
                upload.responseJSON
                    { response in
                        //print response.result
                        if response.result.value != nil
                        {
                            let dict :NSDictionary = response.result.value! as! NSDictionary
                            let status = dict.value(forKey: "status")as! String
                            if status=="1"
                            {
                                print("DATA UPLOAD SUCCESSFULLY")
                            }
                        }
                }
            case .failure(let encodingError):
                let temp = url2
                break
            }
        }*/
        
        
       /* Alamofire.upload(multipartFormData: { multipartFormData in
            if let imageData = UIImageJPEGRepresentation(image!, 1) {
                multipartFormData.append(imageData, withName: "file", fileName: "ЦК_03.11.17_69513432_1025342.jpg", mimeType: "image/png")
            }
            
           // for (key, value) in parameters {
            //    multipartFormData.append((value.data(using: .utf8))!, withName: key)
           // }
            //
            // to: "upload_url", method: .post, headers: ["Authorization": "auth_token"],
        }, to: url,
                encodingCompletion: { encodingResult in
                    switch encodingResult {
                    case .success(let upload, _, _):
                        upload.response { [weak self] response in
                            guard let strongSelf = self else {
                                return
                            }
                            debugPrint(response)
                        }
                    case .failure(let encodingError):
                        print("error:\(encodingError)")
                    }
        })*/
    }
    
    @IBAction func DeleteImage(_ sender: Any)
    {
        let button = sender as! UIButton
        let tag = button.tag/1000
        let image = self.view.viewWithTag(tag) as? UIImageView
        button.isHidden = true
        if (photoForSend[tag/1000] != nil)
        {
            image?.image = UIImage(named: "placeholder.png")
            photoForSend[tag/1000] = nil
            button.isHidden = true
        }
    }
    
  @IBAction func scanInPreviewAction(_ sender: Any) {
    guard checkScanPermissions(), !reader.isRunning else { return }

    previewView.setupComponents(showCancelButton: false, showSwitchCameraButton: false, showTorchButton: false, showOverlayView: true, reader: reader)

    reader.startScanning()
    reader.didFindCode = { result in
      let alert = UIAlertController(
        title: "Hi there!",
        message: String (format:"%@ (of type %@)", result.value, result.metadataType),
        preferredStyle: .alert
      )
      alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
    }
  }

    /*@IBAction func galButtonTapped(_ sender: UIButton) { // Кнопка открытия галереи
        
        currentImage = sender.tag/1000
        let imagePicker = UIImagePickerController() // 1
        imagePicker.delegate = self // 2
        self.present(imagePicker, animated: true, completion: nil) // 3
        
    }*/
    
    @IBAction func camButtonTapped(_ sender: UIButton) { // Нажата кнопка камеры
        currentImage = sender.tag/1000
        let imagePicker = UIImagePickerController() // 1
        imagePicker.delegate = self // 2
        imagePicker.sourceType = UIImagePickerControllerSourceType.camera // 3
        // для выбора только фотокамеры, не для записи видео
        imagePicker.showsCameraControls = true // 4
        self.present(imagePicker, animated: true, completion: nil) // 5
    }
    
    
  // MARK: - QRCodeReader Delegate Methods

    
    
    
  func reader(_ reader: QRCodeReaderViewController, didScanResult result: QRCodeReaderResult) {
    reader.stopScanning()

    dismiss(animated: true) { [weak self] in
      
        self?.SendGetRequest(result.value)
        /*let alert = UIAlertController(
        title: "Hi there2!",
        message: String (format:"%@ (of type %@)", result.value, result.metadataType),
        preferredStyle: .alert
      )
      alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))

      self?.present(alert, animated: true, completion: nil)*/
    }
  }

  func reader(_ reader: QRCodeReaderViewController, didSwitchCamera newCaptureDevice: AVCaptureDeviceInput) {
    print("Switching capturing to: \(newCaptureDevice.device.localizedName)")
  }

  func readerDidCancel(_ reader: QRCodeReaderViewController) {
    reader.stopScanning()

    dismiss(animated: true, completion: nil)
  }

    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    struct jsonResult: Codable
    {
        let attributes:Attributes?
    }
    
    struct Attributes: Codable
    {
        let BaseCode: String
        let DocumentType: String
        let DocumentNum: String
        let DocumentDate: String
        let CommonScans: [Photo]?
        let Lines: [LinesNum]?
    }
    
    
    struct Photo: Codable
    {
        let name: String?
        let path: String?
    }
    
    struct LinesNum: Codable
    {
        let ItemID: String
        let LineNumber: Int
        let Scans: [Photo]?
    }
    
    struct Scans: Codable
    {
        let photos: [Photo]?
    }
    struct Lines: Codable
    {
        let lines: [LinesNum]?
    }
    
    var opacity: Float = 0
    var offset = CGSize(width: 0, height: 0)
    var radius: CGFloat = 0
    
    var fonts: Dictionary<Int,String> = [:]
    
    var coun = 1
    
    @IBOutlet weak var label1: UILabel!
    @IBOutlet weak var label2: UILabel!
    @IBOutlet weak var bottom11: UIButton!
    @IBOutlet weak var bottom12: UIButton!
    @IBOutlet weak var bottom13: UIButton!
    @IBOutlet weak var bottom14: UIButton!
    @IBOutlet weak var bottom15: UIButton!
    @IBOutlet weak var bottom16: UIButton!
    @IBOutlet weak var bottom17: UIButton!
    @IBOutlet weak var bottom18: UIButton!
    
   // button.layer.shadowOpacity = 0.1
    //button.layer.shadowOffset = CGSize(width: 2, height: 2)
    //button.layer.shadowRadius = 1
    
    @IBAction func func1(_ sender: UIButton) {
        opacity = opacity + 0.1
        label1.layer.shadowOpacity = opacity
        label2.layer.shadowOpacity = opacity
    }
    
    @IBAction func func2(_ sender: UIButton) {
        opacity = opacity - 0.1
        label1.layer.shadowOpacity = opacity
        label2.layer.shadowOpacity = opacity
    }
    
    @IBAction func func3(_ sender: UIButton) {
        offset.width = offset.width + 1
        offset.height = offset.height + 1
        label1.layer.shadowOffset = offset
        label2.layer.shadowOffset = offset
    }
    @IBAction func func4(_ sender: UIButton) {
        offset.width = offset.width - 1
        offset.height = offset.height - 1
        label1.layer.shadowOffset = offset
        label2.layer.shadowOffset = offset
    }
    @IBAction func func5(_ sender: UIButton) {
        radius = radius + 1
        label1.layer.shadowRadius = radius
        label2.layer.shadowRadius = radius
    }
    @IBAction func func6(_ sender: UIButton) {
        radius = radius - 1
        label1.layer.shadowRadius = radius
        label2.layer.shadowRadius = radius
    }
    @IBAction func func7(_ sender: UIButton) {
        if (coun<13)
        {
            coun = coun + 1
            label1.font = UIFont(name: fonts[coun]!, size: 20)
            label2.font = UIFont(name: fonts[coun]!, size: 20)
        }
        
    }
    @IBAction func func8(_ sender: UIButton) {
        if (coun>1)
        {
            coun = coun - 1
            label1.font = UIFont(name: fonts[coun]!, size: 20)
            label2.font = UIFont(name: fonts[coun]!, size: 20)
        }
        
    }
    
    /*The entitlements specified in your application’s Code Signing Entitlements file are invalid, not permitted, or do not match those specified in your provisioning profile. (0xE8008016).*/
    
}

extension ViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    // UIImagePickerControllerDelegate
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        let imageFromPC = info[UIImagePickerControllerOriginalImage] as! UIImage // 1
        var image = self.view.viewWithTag(100 + currentImage * 1000) as? UIImageView
        image!.image = imageFromPC // 2
        photoForSend[currentImage] = true
        
       // *1000
        //SendPhoto.isEnabled = true
        //pictureView.image = imageFromPC // 2
        //var tmpButton = self.view.viewWithTag() as? UIImageView
        
        let btn = self.view.viewWithTag(image!.tag*1000) as? UIButton
        btn?.isHidden = false
        self.dismiss(animated: true, completion: nil) // 3
    }
    
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        self.dismiss(animated: true, completion: nil)
    }
}
