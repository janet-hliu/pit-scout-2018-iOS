//
//  TimerTableViewCell.swift
//  DropboxPhotoTest
//
//  Created by Rebecca Hirsch on 2/4/18.
//  Copyright © 2018 citruscircuits. All rights reserved.
//

import UIKit

class TimerTableViewCell: UITableViewCell {

    @IBOutlet weak var dataPoint: UILabel!
    @IBOutlet weak var value: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
}
