//
//  InviteContactsView.swift
//  Jimo
//
//  Created by Gautam Mekkat on 3/2/21.
//

import SwiftUI
import Combine
import Contacts
import PhoneNumberKit


private struct Contact: Identifiable {
    var id = UUID()
    var name: String
    var phoneNumber: String
    var formattedNumber: String
    var photo: Data?
}

private class ContactStore: ObservableObject {
    private static let phoneNumberKit = PhoneNumberKit()

    @Published var contacts: [Contact]?
    @Published var error: Error?
    @Published var loading = false

    func loadContacts(appState: AppState) {
        self.loading = true
        DispatchQueue.global(qos: .userInitiated).async {
            self.fetchContactsCallback { contacts, error in
                DispatchQueue.main.async {
                    if let error = error {
                        self.error = error
                        self.loading = false
                    } else if let contacts = contacts {
                        self.contacts = contacts
                        self.loading = false
                    }
                }
            }
        }
    }

    private func fetchContactsCallback(_ handler: @escaping ([Contact]?, Error?) -> Void) {
        PermissionManager.shared.requestContacts { granted, error in
            if let error = error {
                handler(nil, error)
                return
            }
            if granted {
                let keys = [CNContactFormatter.descriptorForRequiredKeys(for: .fullName),
                            CNContactImageDataKey as CNKeyDescriptor,
                            CNContactPhoneNumbersKey as CNKeyDescriptor]
                let request = CNContactFetchRequest(keysToFetch: keys)
                request.sortOrder = .givenName
                do {
                    var formattedArray: [Contact] = []
                    let formatter = CNContactFormatter()
                    formatter.style = .fullName
                    try PermissionManager.shared.contactStore.enumerateContacts(with: request, usingBlock: { contact, _ in
                        if let number = contact.phoneNumbers.first?.value.stringValue,
                           let name = formatter.string(from: contact),
                           let parsed = try? ContactStore.phoneNumberKit.parse(number) {
                            let number = ContactStore.phoneNumberKit.format(parsed, toType: .e164)
                            let formattedNumber = ContactStore.phoneNumberKit.format(parsed, toType: .international)
                            formattedArray.append(Contact(name: name,
                                                          phoneNumber: number,
                                                          formattedNumber: formattedNumber,
                                                          photo: contact.imageData))
                        }
                    })
                    handler(formattedArray, nil)
                } catch {
                    handler(nil, error)
                }
            } else {
                print("Error when getting contacts, defaulting to empty list")
                handler([], nil)
            }
        }
    }
}

private enum ContactViewAlert {
    case confirmInvite, confirmSendMessage, error(String)
}

private struct ContactView: View {
    @EnvironmentObject var appState: AppState
    @State private var showAlert = false
    @State private var alertType: ContactViewAlert = .confirmInvite
    @State private var inviteCancellable: Cancellable?

    let contact: Contact
    @Binding var loading: Bool

    private func alert(_ type: ContactViewAlert) {
        alertType = type
        showAlert = true
    }

    private func invite() {
        loading = true
        print("Inviting")
        self.inviteCancellable = appState.inviteUser(phoneNumber: contact.phoneNumber)
            .sink(receiveCompletion: { completion in
                self.loading = false
                if case .failure = completion {
                    self.alert(.error("Failed to invite user"))
                }
            }, receiveValue: { inviteStatus in
                self.loading = false
                if inviteStatus.invited {
                    self.alert(.confirmSendMessage)
                } else {
                    self.alert(.error(inviteStatus.message ?? "You have reached your invite limit!"))
                }
            })
    }

    private func sendMessage() {
        let sms: String = "sms:+\(contact.phoneNumber)&body=Check out the places I posted on Jimo! 😘"
            + "\n\nhttps://apps.apple.com/app/id1541360118"
        let url: String = sms.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
        Analytics.shared.logInviteContact()
        UIApplication.shared.open(URL(string: url)!, options: [:], completionHandler: nil)
    }

    var profilePicture: Image {
        if let data = contact.photo,
           let image = UIImage(data: data) {
            return Image(uiImage: image)
        } else {
            return Image(systemName: "person.crop.circle")
        }
    }

    var body: some View {
        VStack {
            profilePicture
                .resizable()
                .foregroundColor(.gray)
                .background(Color.white)
                .scaledToFill()
                .frame(width: 80, height: 80)
                .cornerRadius(40)

            Text(contact.name)
                .font(.system(size: 12))
        }
        .frame(minHeight: 120)
        .onTapGesture {
            hideKeyboard()
            self.sendMessage()
        }
        .simultaneousGesture(DragGesture().onChanged { _ in
            hideKeyboard()
        })
        .alert(isPresented: $showAlert) {
            switch alertType {
            case .confirmInvite:
                return Alert(title: Text("Confirm invite"),
                             message: Text("Invite \(contact.name) (\(contact.formattedNumber)) to Jimo?"),
                             primaryButton: .default(Text("Invite")) { self.invite() },
                             secondaryButton: .cancel())
            case .confirmSendMessage:
                return Alert(title: Text("Invited \(contact.name)!"),
                             message: Text("Send a message to let them know they're invited."),
                             primaryButton: .default(Text("Ok")) { self.sendMessage() },
                             secondaryButton: .cancel())
            case let .error(message):
                return Alert(title: Text("Failed to invite \(contact.name)."),
                             message: Text(message),
                             primaryButton: .default(Text("Ok")),
                             secondaryButton: .cancel())
            }
        }
    }
}


struct InviteContactsView: View {
    @EnvironmentObject var appState: AppState

    @StateObject private var contactStore: ContactStore = ContactStore()
    @State private var filter: String = ""
    @State private var loading = false

    private var columns: [GridItem] = [
        GridItem(.flexible(minimum: 50), spacing: 10),
        GridItem(.flexible(minimum: 50), spacing: 10),
        GridItem(.flexible(minimum: 50), spacing: 10)
    ]

    private var filteredContacts: [Contact]? {
        if let contacts = contactStore.contacts, filter.count > 0 {
            return contacts.filter({ $0.name.lowercased().contains(filter.lowercased()) })
        } else {
            return contactStore.contacts
        }
    }

    var body: some View {
        VStack {
            if contactStore.loading {
                ProgressView()
            }

            if let contacts = filteredContacts {
                ZStack {
                    VStack {
                        TextField("Filter contacts", text: $filter)
                            .autocapitalization(.words)
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.gray, style: StrokeStyle(lineWidth: 2)))
                            .padding(12)

                        ScrollView {
                            LazyVGrid(columns: columns) {
                                ForEach(contacts) { contact in
                                    ContactView(contact: contact,
                                                loading: $loading)
                                }
                            }
                        }
                        .gesture(DragGesture().onChanged { _ in
                            hideKeyboard()
                        })
                    }

                    if self.loading {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color("background").opacity(0.5))

                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            if contactStore.error != nil {
                VStack {
                    Button(action: {
                        UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
                    }) {
                        Text("Enable access to your contacts to invite friends to Jimo.")
                            .multilineTextAlignment(.center)
                    }
                    Text("We value and respect your privacy. We do not store your contacts on our servers or share them with anyone else.")
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.top, 5)
                        .font(.caption)
                }
                .padding(.horizontal, 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            contactStore.loadContacts(appState: appState)
        }
        .foregroundColor(Color("foreground"))
        .background(Color("background").edgesIgnoringSafeArea(.all))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarColor(UIColor(Color("background")))
        .toolbar(content: {
            ToolbarItem(placement: .principal) {
                NavTitle("Invite your friends to Jimo")
            }
        })
    }
}
