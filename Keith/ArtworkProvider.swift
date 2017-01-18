//
//  ArtworkProvider.swift
//  Keith
//
//  Created by Rafael Alencar on 18/01/17.
//  Copyright © 2017 Movile. All rights reserved.
//

import UIKit

public protocol ArtworkProviding: class {
    func getArtwork(for url: URL, completionHandler: @escaping (UIImage?) -> Void)
}

public final class ArtworkProvider: ArtworkProviding {
    
    private var task: URLSessionDownloadTask?
    
    public init() {}
    
    public func getArtwork(for url: URL, completionHandler: @escaping (UIImage?) -> Void) {
        
        let configuration = URLSessionConfiguration.default
        let session = URLSession(configuration: configuration)
        let request = URLRequest(url: url)
        
        task = session.downloadTask(with: request) { (fileUrl, urlResponse, error) in
            guard error == nil else {
                KeithLog("Failed to download artwork with error: \(error).")
                
                DispatchQueue.main.async {
                    completionHandler(nil)
                }
                
                return
            }
            
            guard let fileUrl = fileUrl else {
                KeithLog("File URL for downloaded artwork is nil.")
                
                DispatchQueue.main.async {
                    completionHandler(nil)
                }
                
                return
            }
            
            let imageData: Data
            
            do {
                imageData = try Data(contentsOf: fileUrl)
            }
            catch {
                KeithLog("Couldn't read contents of file.")
                
                DispatchQueue.main.async {
                    completionHandler(nil)
                }
                
                return
            }
            
            guard let image = UIImage(data: imageData) else {
                KeithLog("Couldn't read data into an image representation.")
                
                DispatchQueue.main.async {
                    completionHandler(nil)
                }
                
                return
            }
            
            DispatchQueue.main.async {
                completionHandler(image)
            }
            
            return
        }
        
        task?.resume()
    }
    
    deinit {
        task?.cancel()
    }
}
