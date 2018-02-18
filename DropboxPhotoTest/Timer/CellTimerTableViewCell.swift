//
//  CellTimerTableViewCell.swift
//  DropboxPhotoTest
//
//  Created by Janet Liu on 2/14/18.
//  Copyright © 2018 citruscircuits. All rights reserved.
//

import UIKit

class CellTimerTableViewCell: UITableViewCell {
    
    @IBOutlet weak var trialNumber: UILabel!
    @IBOutlet weak var timerValue: UILabel!
    @IBOutlet weak var didSucceed: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        
        // Configure the view for the selected state
    }
    
}

